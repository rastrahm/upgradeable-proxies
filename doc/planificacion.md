# Planificación — Módulo 11: Upgradeable Proxies (UUPS & Transparent)

**Estado:** Fases **0–6** ✅ completadas. Módulo cerrado a nivel de planificación v1.  
**Regla de avance:** cada fase requiere **autorización explícita** del responsable antes de empezar.

---

## 1. Objetivo

Construir un conjunto de contratos proxy upgradeables de nivel producción con:

- Patrón **Transparent Proxy** (ERC-1967) + admin separado.
- Patrón **UUPS** con autorización de upgrade en la implementación (`_authorizeUpgrade`).
- Slots EIP-1967 correctos; `delegatecall` en fallback (assembly).
- Inicialización segura (`Initializable` + `_disableInitializers()`).
- Gaps de storage (`uint256[50] __gap`) para evitar colisiones en upgrades.
- Stack: **Foundry + Solidity `0.8.24`** (pragma fijo).

---

## 2. Alcance

| Incluido | Excluido (v1) |
|----------|----------------|
| Proxy ERC-1967, Transparent, UUPS, impl V1/V2, tests, storage-layout | Beacon Proxy / Diamond (EIP-2535) |
| Admin / owner 2-step para upgrades | Gobernanza DAO del upgrade |
| Custom errors del módulo | Proxy factory multi-clone compleja |
| Fuzz + tests de upgrade no autorizado | Frontend (fase opcional posterior) |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite`)

- Solidity **exacto** `0.8.24`.
- OpenZeppelin Contracts v5.x donde aporte herencia auditada (o implementación propia alineada a EIP-1967).
- Foundry: unit + fuzz (`runs >= 1000`) + `forge inspect <Contract> storage-layout`.
- Custom errors (no `require` con strings).
- CEI / access control en funciones administrativas.
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Módulo 11

- Slot implementación: `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)`.
- Slot admin (Transparent): `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`.
- Routing solo vía `delegatecall` en fallback/assembly; preservar `msg.sender` y `msg.value`.
- Constructores de implementación deshabilitados con `_disableInitializers()`.
- Upgrades solo por admin / `_authorizeUpgrade`.

---

## 4. Arquitectura prevista

```
11-upgradeable-proxies/
├── doc/                          ← planificación y diagramas (esta carpeta)
├── src/
│   ├── proxy/
│   │   ├── ERC1967Proxy.sol      # base: slot impl + fallback delegatecall
│   │   ├── TransparentProxy.sol  # admin vs usuario (function clash guard)
│   │   └── ProxyAdmin.sol        # dueño del transparent; upgradeToAndCall
│   ├── uups/
│   │   └── UUPSUpgradeable.sol   # upgradeToAndCall + _authorizeUpgrade
│   ├── utils/
│   │   └── Initializable.sol     # initializer / reinitializer / disable
│   ├── implementations/
│   │   ├── BoxV1.sol             # estado de ejemplo + gap
│   │   └── BoxV2.sol             # nueva lógica; layout compatible
│   └── interfaces/
│       ├── ITransparentProxy.sol
│       ├── IUUPSUpgradeable.sol
│       └── IBox.sol
├── test/
│   ├── TransparentProxy.t.sol
│   ├── UUPS.t.sol
│   ├── UpgradePersistence.t.sol
│   ├── UnauthorizedUpgrade.t.sol
│   └── fuzz/StorageUpgrade.fuzz.t.sol
├── script/
│   └── Deploy.s.sol
├── foundry.toml
└── remappings.txt
```

### Contratos y responsabilidades

| Contrato | Responsabilidad |
|----------|-----------------|
| `ERC1967Proxy` | Almacena impl en slot EIP-1967; `delegatecall` en fallback |
| `TransparentProxy` | Si `msg.sender == admin` → funciones de admin; si no → delegatecall a impl |
| `ProxyAdmin` | Único caller privilegiado del Transparent para upgrades |
| `UUPSUpgradeable` | Lógica de upgrade en la impl; `_authorizeUpgrade` |
| `Initializable` | `initializer` / protección contra re-init |
| `BoxV1` / `BoxV2` | Demo de estado + upgrade con persistencia |

---

## 5. Errores custom (obligatorios del módulo)

```solidity
error InvalidImplementation();
error AlreadyInitialized();
error UnauthorizedUpgrade();
error DelegateCallFailed();
```

Ampliar solo si hace falta (p. ej. `ZeroAddress()`, `InvalidAdmin()`), siempre como custom errors.

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta que digas explícitamente: *“autorizo Fase N”* (o equivalente). |
| **Entrega** | Al cerrar una fase: checklist de aceptación + resumen de archivos tocados. |
| **Bloqueo** | Si aparece alcance nuevo, se documenta y se espera nueva autorización. |
| **TDD** | Dentro de cada fase de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + estructura | ✅ Completada | ✅ Autorizada |
| 1 | Core ERC-1967 + `delegatecall` | ✅ Completada | ✅ Autorizada |
| 2 | Transparent Proxy + `ProxyAdmin` | ✅ Completada | ✅ Autorizada |
| 3 | UUPS + `Initializable` | ✅ Completada | ✅ Autorizada |
| 4 | Implementaciones BoxV1 / BoxV2 + gaps | ✅ Completada | ✅ Autorizada |
| 5 | Suite de tests (persistencia, unauthorized, fuzz, storage-layout) | ✅ Completada | ✅ Autorizada |
| 6 | Scripts de deploy + hardening NatSpec / SWC + gas | ✅ Completada | ✅ Autorizada |

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry ✅

**Objetivo:** repo compilable vacío con tooling listo.

1. `forge init` (o estructura mínima compatible con la suite).
2. `foundry.toml`: solc `0.8.24`, fuzz runs ≥ 1000.
3. Dependencias OZ v5 si se reutilizan primitivas.
4. Carpetas `src/`, `test/`, `script/`, `doc/` (ya creada).

**Criterio de salida:** `forge build` OK sin contratos de negocio aún (o con stub).

**Hecho (2026-09-08):** `foundry.toml` + `remappings.txt`; `forge-std` + OZ `v5.2.0` en `lib/` (gitignored); stub `Placeholder` + smoke test; carpetas `src/{proxy,uups,utils,implementations,interfaces}` y `test/fuzz` preparadas. `forge build` y `forge test` en verde.

---

### Fase 1 — Core ERC-1967 + delegatecall ✅

**Objetivo:** proxy mínimo que enruta calldata a la implementación.

1. Tests: deploy proxy → call vía proxy muta storage del proxy (no de la impl).
2. Implementar lectura/escritura del slot de implementación EIP-1967.
3. Fallback/receive en assembly con `delegatecall`; fallo → `DelegateCallFailed`.
4. Validar `implementation != address(0)` → `InvalidImplementation`.

**Criterio de salida:** llamada a través del proxy persiste estado en la dirección del proxy.

**Hecho:** `ERC1967Proxy`, `ProxyErrors`, mock `CounterLogic`, suite `test/ERC1967Proxy.t.sol` (slot EIP-1967, persistencia, `msg.value`, init data, errores). Stub `Placeholder` eliminado.

---

### Fase 2 — Transparent Proxy + ProxyAdmin ✅

**Objetivo:** separar camino admin vs usuario (evitar function clashes).

1. Tests: usuario llama función de la impl → delegatecall; admin llama upgrade → no delegatecall a selector de usuario.
2. Slot admin EIP-1967.
3. `ProxyAdmin` con `upgradeToAndCall` y ownership (`Ownable2Step` preferible).
4. Revert `UnauthorizedUpgrade` si no-admin intenta upgrade.

**Criterio de salida:** clash admin/usuario cubierto por tests.

**Hecho:** `TransparentProxy` (dispatch admin en fallback), `ProxyAdmin` (`Ownable2Step`), mocks `CounterLogicV2` / `ClashingLogic`, suite `test/TransparentProxy.t.sol`.

---

### Fase 3 — UUPS + Initializable ✅

**Objetivo:** upgrade autorizado desde la implementación.

1. Tests: `upgradeToAndCall` solo tras `_authorizeUpgrade` OK.
2. `UUPSUpgradeable` con proxiable UUID / check de ERC-1967.
3. `Initializable`: un solo `initialize`; constructor llama `_disableInitializers()`.
4. Reverts: `AlreadyInitialized`, `UnauthorizedUpgrade`, `InvalidImplementation`.

**Criterio de salida:** UUPS upgrade feliz + caminos de error en verde.

**Hecho:** `Initializable`, `UUPSUpgradeable`, mocks `UUPSCounter` / `UUPSCounterV2` / `NonUUPSLogic`, suite `test/UUPS.t.sol`.

---

### Fase 4 — BoxV1 / BoxV2 + storage gaps ✅

**Objetivo:** demo de negocio upgradeable con layout seguro.

1. `BoxV1`: estado (`value`, `owner`, …) + `uint256[50] __gap`.
2. `BoxV2`: nuevas funciones / variables **solo al final** del layout (tras gap o reduciendo gap).
3. Tests: set estado en V1 → upgrade a V2 → mismos valores.
4. `forge inspect BoxV1 storage-layout` y `BoxV2 storage-layout` documentados.

**Criterio de salida:** persistencia de estado verificada; layouts compatibles.

**Hecho:** `IBox`, `BoxV1`, `BoxV2`, `test/BoxUpgrade.t.sol`, `doc/storage-layout.md` (slots 0/1 estables; `label` en slot 2; gap 50→49).

---

### Fase 5 — Suite de tests completa ✅

**Objetivo:** requisitos de testing del `.cursorrules` del módulo.

| Tipo | Qué valida |
|------|------------|
| Unit e2e | Deploy → mutate → upgrade → assert estado |
| Unauthorized | No-admin no puede `upgradeToAndCall` |
| Storage layout | Compatibilidad V1↔V2 (`forge inspect`) |
| Fuzz | Variables de estado pre/post upgrade sin corrupción |

**Criterio de salida:** `forge test` verde; fuzz sin fallos inesperados.

**Hecho:** `test/UpgradeE2E.t.sol`, `test/attack/UnauthorizedUpgrade.t.sol`, `test/fuzz/StorageUpgrade.fuzz.t.sol` (1000 runs), `doc/SWC-AUDIT.md` (estilo módulo 10). **54 PASS**.

---

### Fase 6 — Deploy + hardening + gas ✅

1. `script/Deploy.s.sol` (Transparent y UUPS).
2. NatSpec completo; checklist SWC relevante a proxies.
3. `doc/SWC-AUDIT.md` / `doc/GAS.md` al estilo de módulos previos.

**Criterio de salida:** deploy local reproducible + docs de seguridad + gas documentado.

**Hecho:** Deploy UUPS+Transparent; gas opts (admin `immutable`, sin extcodesize en hot path, calldata upgrades, slots precomputados); `test/gas/Proxy.gas.t.sol`; `doc/GAS.md`. **60 PASS**.

---

## 8. Matriz de pruebas (objetivo global)

| Caso | Qué valida |
|------|------------|
| Persistencia post-upgrade | Storage del proxy intacto tras cambiar impl |
| Unauthorized upgrade | `UnauthorizedUpgrade` |
| Double init | `AlreadyInitialized` |
| Impl cero / inválida | `InvalidImplementation` |
| Delegatecall fail | `DelegateCallFailed` |
| Transparent clash | Admin no ejecuta lógica de usuario por error |
| Fuzz estado | Cero corrupción de slots usados |

---

## 9. Seguridad (checklist vivo)

- [x] Slots EIP-1967 correctos (no storage ordinario de la impl).
- [x] `_disableInitializers()` en constructores de implementaciones.
- [x] Gaps `__gap` en bases upgradeables.
- [x] Upgrades con access control estricto.
- [x] `delegatecall` solo en proxy; sin lógica de negocio en el proxy (salvo admin path Transparent).
- [x] Custom errors del módulo.
- [x] Sin floating pragma; NatSpec en APIs públicas.
- [x] Suite attack + fuzz + `doc/SWC-AUDIT.md`.

---

## 10. Entregables de documentación (`doc/`)

| Archivo | Contenido |
|---------|-----------|
| `planificacion.md` | Este documento (fases + gates) |
| `diagrama-de-clases.md` | Estructura y relaciones entre contratos |
| `diagrama-de-flujo.md` | Flujos de decisión (init, upgrade, routing) |
| `flujograma.md` | Flujos actor–sistema extremo a extremo |
| `storage-layout.md` | Layout BoxV1/BoxV2 (`forge inspect`) |
| `SWC-AUDIT.md` | Matriz SWC-100–136 + riesgos informativos |
| `GAS.md` | Optimizaciones y benchmarks Fase 6 |

---

## 11. Criterios de aceptación del módulo

1. Compila con `pragma solidity 0.8.24`.
2. Transparent y UUPS operativos con tests e2e.
3. Estado persiste tras upgrade V1 → V2.
4. Upgrades no autorizados revierten.
5. `forge inspect` confirma layouts compatibles.
6. Fuzz de estado pre/post upgrade en verde.
7. NatSpec + custom errors en APIs públicas.

---

## 12. Próximo paso

**Módulo v1 completo (Fases 0–6).** Posibles extensiones: Timelock en upgrades, invariantes Foundry, frontend.

**Nota:** usa `~/.foundry/bin/forge` (o antepón `$HOME/.foundry/bin` al `PATH`); el `forge` de nvm/npm no es Foundry.
