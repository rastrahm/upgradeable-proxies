# Entender el módulo — Decisiones, lógica y gas

Documento para leer el proyecto **Upgradeable Proxies (módulo 11)** sin tener que reconstruir el diseño desde el código.

Relacionado: [`planificacion.md`](./planificacion.md) · [`GAS.md`](./GAS.md) · [`SWC-AUDIT.md`](./SWC-AUDIT.md) · [`flujograma.md`](./flujograma.md)

---

## 1. Idea en una frase

El **proxy** es la dirección fija que usan los usuarios. La **implementación** es el código que se ejecuta. El estado vive en el proxy. Cambiar de versión = cambiar un puntero (slot EIP-1967), no migrar balances a otro contrato.

```
Usuario ──► Proxy (storage + dirección estable)
                │
                │  delegatecall
                ▼
         Implementation V1 / V2 (solo lógica)
```

---

## 2. Decisiones técnicas (por qué se hizo así)

### 2.1 Dos patrones, no uno

| Patrón | Dónde vive el control de upgrade | Por qué existe |
|--------|----------------------------------|----------------|
| **Transparent** | Contrato aparte (`ProxyAdmin`) | Evita *function clash*: el admin nunca ejecuta la lógica de negocio por error |
| **UUPS** | Dentro de la implementación (`_authorizeUpgrade`) | Menos contratos en el camino; el proxy es más “tonto” y barato |

**Decisión:** implementar **ambos** para aprender el tradeoff real (gas, superficie de ataque, DX), no elegir uno a ciegas.

### 2.2 EIP-1967 para el puntero de lógica

No guardar `address implementation` en el slot 0 del proxy.

**Por qué:** el slot 0 lo usará la lógica de negocio vía `delegatecall`. Si el proxy y la impl pelean por el mismo slot → corrupción de storage.

**Decisión:** slots canónicos:

- implementación: `keccak256("eip1967.proxy.implementation") - 1`
- admin (Transparent): `keccak256("eip1967.proxy.admin") - 1`

### 2.3 `delegatecall`, no `call`

Con `call`, el estado se escribiría en la implementación. Con `delegatecall`, se escribe en el **proxy** y se preservan `msg.sender` / `msg.value`.

**Decisión:** todo el routing de usuario pasa por `delegatecall` en assembly (fallback / receive).

### 2.4 Initializable + `_disableInitializers()`

Los constructores de la impl **no** inicializan el storage del proxy (el constructor corre en la dirección de la impl).

**Decisión:**

1. Constructor de Box/UUPS llama `_disableInitializers()` → nadie puede “tomar” la impl suelta.
2. `initialize(...)` se llama **vía proxy** (calldata del constructor del proxy o después, controlado).

### 2.5 Storage gaps (`__gap`)

BoxV1 reserva `uint256[50] __gap`. BoxV2 añade `label` y baja el gap a 49.

**Decisión:** variables nuevas **solo al final** del layout. Documentado en [`storage-layout.md`](./storage-layout.md) con `forge inspect`.

### 2.6 Admin immutable en Transparent (Fase 6)

OZ v5 también fija el admin como immutable.

**Decisión:**

- Routing usa `_adminAddress` (immutable) → sin SLOAD en cada call de usuario.
- Se escribe el slot EIP-1967 **una vez** en el constructor (compatibilidad `eth_getStorageAt`).
- **No** hay `changeAdmin` en el proxy: rotar control = `transferOwnership` / `acceptOwnership` del `ProxyAdmin`.

### 2.7 Custom errors del módulo

`InvalidImplementation`, `AlreadyInitialized`, `UnauthorizedUpgrade`, `DelegateCallFailed`.

**Decisión:** reverts baratos y tipados; alineado a la suite (sin `require` con strings).

### 2.8 Qué se dejó fuera (a propósito)

| Excluido v1 | Motivo |
|-------------|--------|
| Beacon / Diamond | Otro módulo de complejidad |
| Timelock / DAO en upgrades | Trust del owner documentado como riesgo informativo |
| Frontend | Fuera del alcance de contratos |

---

## 3. Lógica que sigue el sistema

### 3.1 Flujo feliz — UUPS (Box)

```
1. Deploy BoxV1          → constructor deshabilita initializers
2. Deploy ERC1967Proxy(impl, initData)
                         → escribe slot impl
                         → delegatecall initialize(owner, value)
3. Usuario: store(x)     → fallback → delegatecall → storage del PROXY
4. Owner: upgradeToAndCall(BoxV2, initializeV2)
                         → delegatecall a V1.upgradeToAndCall
                         → _authorizeUpgrade (solo owner)
                         → valida proxiableUUID de V2
                         → escribe slot → V2
                         → delegatecall initializeV2
5. Usuario: retrieve()   → mismo valor; version() == "2"
```

### 3.2 Flujo feliz — Transparent

```
1. Deploy ProxyAdmin(owner)
2. Deploy TransparentProxy(impl, admin=ProxyAdmin, data?)
3. Usuario → proxy → delegatecall a lógica
4. Owner → ProxyAdmin.upgradeAndCall(proxy, newImpl, data)
        → proxy ve msg.sender == admin → path admin (NO delegatecall de negocio)
        → cambia slot impl
```

### 3.3 Reglas de routing (Transparent)

| Quién llama | Qué pasa |
|-------------|----------|
| `msg.sender != admin` | Siempre `delegatecall` a la impl (aunque el selector se llame `upgradeToAndCall`) |
| `msg.sender == admin` y selector `upgradeToAndCall` | Upgrade real en el proxy |
| `msg.sender == admin` y otro selector | `UnauthorizedUpgrade` (admin no usa el proxy como wallet de usuario) |

### 3.4 Reglas de upgrade (UUPS)

| Check | Si falla |
|-------|----------|
| Llamada vía proxy (`onlyProxy`) | `UnauthorizedUpgrade` |
| `_authorizeUpgrade` (p. ej. owner) | `UnauthorizedUpgrade` |
| Nueva impl sin código / UUID incorrecto / no UUPS | `InvalidImplementation` |
| Segundo `initialize` | `AlreadyInitialized` |

### 3.5 Mapa mental de responsabilidades

```
ERC1967Proxy     → “cómo enruto” (slot + delegatecall)
TransparentProxy → “quién es admin vs usuario”
ProxyAdmin       → “quién puede pedir el upgrade” (Ownable2Step)
UUPSUpgradeable  → “cómo se autoriza y valida el upgrade desde la lógica”
Initializable    → “cómo se inicia el estado una sola vez”
BoxV1 / BoxV2    → “qué hace el negocio” + gaps
```

---

## 4. Gas: qué ya está optimizado

Resumen de Fase 6 (detalle numérico en [`GAS.md`](./GAS.md)):

1. Admin **immutable** en Transparent.
2. **Sin** `extcodesize` en el hot path del fallback.
3. Slots EIP-1967 como **constants** precomputados.
4. `delegatecall` en **assembly**.
5. Upgrades con **`bytes calldata`** (menos copia a memory).
6. Sin `changeAdmin` on-proxy (menos bytecode).
7. `optimizer_runs = 10_000` + `via_ir`.

Prioridad consciente: **runtime del usuario** (cada `store` / `retrieve`) > coste de deploy.

---

## 5. ¿Se puede mejorar más el gas?

Sí, pero casi todo es **marginal** o tiene un **coste de seguridad / claridad**. Nada de esto es “gratis”.

### 5.1 Mejoras posibles (ordenadas por impacto realista)

| Idea | Ahorro esperado | Riesgo / costo | ¿Vale la pena en v1? |
|------|-----------------|----------------|----------------------|
| Quitar getter `implementation()` / `admin()` del ABI del proxy | Deploy + evitar clash de selectores | Ops más incómodas (leer solo storage) | Opcional |
| Minimal proxy (EIP-1167) delante de UUPS solo para clones | Deploy mucho más barato por instancia | No es el mismo producto “proxy upgradeable único” | Otro diseño |
| Empaquetar `owner` + flags en un solo slot en Box | ~1 SLOAD menos en auth/views | Layout + gaps más frágiles | Solo si el negocio crece |
| `version()` como `bytes32` / `uint8` en vez de `string` | Menos gas en call + bytecode | API menos legible | Micro |
| Quitar evento `Upgraded` / `AdminChanged` | Gas en upgrade / deploy | Peor indexación off-chain | No recomendado |
| `ProxyAdmin` propio más minimal (sin Ownable2Step) | Deploy admin más barato | Pierdes 2-step (peor UX/seguridad) | No |
| Assembly aún más agresivo en Transparent `_fallback` | Decenas de gas | Legibilidad / auditoría | Solo si hay benchmark |
| Bajar `optimizer_runs` | Deploy más barato | Runtime más caro | Contrario al objetivo del módulo |

### 5.2 Lo que **no** conviene “optimizar”

| Tentación | Por qué no |
|-----------|------------|
| Meter `implementation` en slot 0 | Colisión con el storage de la lógica |
| Saltar `proxiableUUID` en UUPS | Puedes brickear el proxy upgradando a algo no-UUPS |
| Re-habilitar `extcodesize` en cada call “por si acaso” | Quemas gas en el hot path; el set de impl ya valida |
| Reordenar storage en V2 “para compactar” | Corrompe estado de usuarios |

### 5.3 Dónde sí hay margen serio (fuera del proxy)

El proxy ya es delgado. El gas gordo suele estar en **la lógica de negocio**:

- menos SSTOREs,
- menos lecturas calientes,
- calldata tipado,
- evitar strings dinámicos en hot path.

Ejemplo: en Box, `store` / `retrieve` son casi el mínimo posible; el coste que ves en tests incluye overhead de Foundry + cold storage en el primer write.

### 5.4 Cómo medir antes de tocar

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract ProxyGasTest --gas-report
forge snapshot --match-contract ProxyGasTest
```

Regla: **no mergear una “opt” sin Δ medido** en el mismo test.

---

## 6. Cómo leer el repo (orden sugerido)

1. `src/proxy/ERC1967Proxy.sol` — corazón del routing  
2. `src/proxy/TransparentProxy.sol` + `ProxyAdmin.sol` — admin vs usuario  
3. `src/uups/UUPSUpgradeable.sol` + `src/utils/Initializable.sol` — upgrade desde la lógica  
4. `src/implementations/BoxV1.sol` → `BoxV2.sol` — layout + gap  
5. `test/UpgradeE2E.t.sol` + `test/attack/` + `test/fuzz/` — comportamiento esperado  
6. `doc/GAS.md` + `doc/SWC-AUDIT.md` — tradeoffs y seguridad  

---

## 7. Checklist mental (si mañana lo explicás en una entrevista)

1. Estado en el **proxy**, código en la **impl**.  
2. Puntero en slot **EIP-1967**, no en slot 0.  
3. Transparent separa **quién upgradear**; UUPS mete la auth en la **lógica**.  
4. Init **vía proxy**; impl nace con initializers **bloqueados**.  
5. Gaps para no romper storage en V2.  
6. Gas: barato el **fallback**; no regalar seguridad por 200 gas.  

---

*Última actualización: alineado al código post Fase 6 (admin immutable, suite 60 PASS).*
