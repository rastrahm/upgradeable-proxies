# Patrones de proxy — Beacon, Clones, Diamond + tabla comparativa

> *Beacon* = **faro**. *Minimal proxy* = **vaso** barato. *Diamond* = **edificio con muchas oficinas** (facetas).

Relacionado: [`ENTENDER-EL-MODULO.md`](./ENTENDER-EL-MODULO.md) · módulo 11 (UUPS + Transparent).

---

## 1. Beacon Proxy — explicación detallada

### 1.1 Problema que resuelve

Con UUPS/Transparent **clásicos**, cada proxy guarda **su propio** slot EIP-1967 de implementación.

Si desplegás **1.000 vaults** (uno por usuario) y querés upgradear la lógica de todos:

- sin beacon → 1.000 transacciones `upgradeTo(...)` (o un script carísimo),
- con beacon → **1** cambio en el faro; todos los proxies leen el nuevo destino.

### 1.2 Piezas

```
                 ┌──────────────────────┐
   Owner/Admin ─►│  UpgradeableBeacon   │  ← guarda address implementation
                 │  (el "faro")         │     + función upgradeTo(newImpl)
                 └──────────┬───────────┘
                            │ implementation()
           ┌────────────────┼────────────────┐
           ▼                ▼                ▼
     BeaconProxy A    BeaconProxy B    BeaconProxy C
     (storage user A) (storage user B) (storage user C)
           │                │                │
           └──── delegatecall a la MISMA impl ────┘
```

| Contrato | Rol |
|----------|-----|
| **UpgradeableBeacon** | Contrato pequeño: `implementation()` + `upgradeTo` (solo owner). Es la fuente de verdad. |
| **BeaconProxy** | Proxy por instancia. En cada call: pregunta al beacon “¿cuál es la impl?” → `delegatecall` a esa address. |
| **Implementation** | Lógica compartida. El **estado** de cada usuario vive en **su** BeaconProxy, no en el beacon. |

### 1.3 Flujo de una llamada

```
1. Usuario llama BeaconProxyA.deposit()
2. Fallback del proxy:
   a) beacon.implementation()  →  0xLogicV2
   b) delegatecall(0xLogicV2, calldata)
3. deposit() escribe balances en storage de BeaconProxyA
```

El beacon **no** guarda los deposits. Solo responde: “hoy la lógica es esta”.

### 1.4 Flujo de upgrade

```
1. Owner → UpgradeableBeacon.upgradeTo(LogicV3)
2. BeaconProxyA / B / C no cambian su código
3. En la próxima call, cada proxy pregunta al beacon y ya usa LogicV3
```

Un upgrade → efecto global sobre todas las instancias que apuntan a ese beacon.

### 1.5 Slot / estándar

OpenZeppelin usa el slot EIP-1967 de **beacon**:

`bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)`

El proxy guarda la address del **beacon** (no necesariamente la de la impl). La impl se resuelve en runtime.

### 1.6 Combinación habitual: clones + beacon

A menudo:

1. Desplegás **una** lógica + **un** beacon.
2. Por cada usuario: `clone` (EIP-1167) o `BeaconProxy` barato.
3. Upgrade = tocar el beacon.

Eso da: **deploy barato por instancia** + **upgrade masivo**.

### 1.7 Riesgos específicos del Beacon

| Riesgo | Detalle |
|--------|---------|
| **Blast radius** | Un upgrade malo afecta a **todas** las instancias a la vez |
| **Trust del owner del beacon** | Quien controla el faro controla la lógica de todo el set |
| **Extra call** | Cada tx hace (al menos) una lectura/`STATICCALL` al beacon → un poco más de gas que UUPS con slot local |
| **Layout compartido** | Todas las instancias deben seguir el mismo storage layout de la lógica |

### 1.8 Beacon vs UUPS vs Transparent (intuición)

| | Quién tiene el puntero a la lógica | Upgrade de N instancias |
|--|------------------------------------|-------------------------|
| UUPS / Transparent | Cada proxy | N upgrades |
| Beacon | El faro (compartido) | 1 upgrade |

Beacon no reemplaza UUPS/Transparent del todo: a veces la **impl** detrás del beacon es UUPS… pero lo habitual es: beacon owner upgradear la lógica, y los proxies solo delegan.

---

## 1B. Minimal Proxy (EIP-1167 / clones) — explicación detallada

### ¿Qué es, en una frase?

Un **contrato casi vacío** (~45 bytes de bytecode) cuyo único trabajo es:  
**“lo que me manden, lo reenvío con `delegatecall` a esta implementación fija”.**

No es un proxy “inteligente” como Transparent. Es una **fotocopia barata** de un contrato maestro.

Analogía:

- **Implementación** = el molde / receta.  
- **Clone EIP-1167** = vaso descartable con tu café (tu storage).  
- Todos los vasos usan la **misma** receta, pero cada uno tiene **su** contenido.

### Problema que resuelve

Desplegar 1.000 veces el mismo contrato “gordo” (vault, wallet, account) cuesta una fortuna en gas (bytecode grande × N).

Con clones:

1. Desplegás **una vez** la lógica completa (`Implementation`).  
2. Por cada usuario/instancia desplegás solo un **stub** mínimo que apunta a esa lógica.  
3. Cada clone tiene **su propia address y su propio storage**.

### Cómo funciona técnicamente

El bytecode del minimal proxy es un template fijo. En el medio va **quemada** (hardcoded) la address de la implementación:

```
runtime ≈ 
  calldatacopy
  delegatecall(gas, <IMPLEMENTATION_ADDRESS>, …)
  return / revert
```

- No hay `sload` de un slot EIP-1967 en el clone clásico.  
- La impl está **en el bytecode** del proxy.  
- Por eso el deploy es tan barato: casi no hay código.

OpenZeppelin: `Clones.clone(implementation)` / `Clones.cloneDeterministic(...)`.

### Flujo de una llamada

```
1. Deploy Implementation (lógica completa)        → 0xLogic
2. Factory crea clone(0xLogic)                   → 0xCloneUserA  (bytecode chico)
3. Usuario llama 0xCloneUserA.deposit()
4. Fallback del clone:
      delegatecall(0xLogic, calldata)
5. deposit() escribe en storage de 0xCloneUserA
```

Igual que cualquier proxy: **estado en el clone**, **código en la impl**.

### Inicialización (muy importante)

El **constructor** de la Implementation corre al desplegar `0xLogic`, **no** al crear cada clone.

Por eso las impls clonables:

- usan `initialize(...)` (como upgradeables),
- a menudo `_disableInitializers()` en el constructor de la impl,
- la factory hace: `clone` + `initialize(owner, …)` en la misma tx.

Si no inicializás el clone, queda vacío / tomable por otro.

### `clone` vs `cloneDeterministic` (CREATE2)

| | |
|--|--|
| **clone** | Address nueva “al azar” (según nonce). |
| **cloneDeterministic** | Address **predecible** con `salt` (CREATE2). Útil para “counterfactual” wallets, same address cross-chain con cuidado, etc. |

### ¿El clone es upgradeable?

**El EIP-1167 puro: no.**  
La address de la lógica está **fijada en el bytecode** del clone. No hay `upgradeTo` en el stub.

Para upgradear **todos** los clones:

| Estrategia | Cómo |
|------------|------|
| **Clone → impl fija** | No upgrade (o migración a nuevos clones). |
| **Clone + Beacon** | El “implementation” del clone apunta a un patrón donde la lógica se resuelve vía beacon… *o* usás BeaconProxy en vez de 1167 puro. En la práctica: **BeaconProxy / clones que delegan a un proxy upgradeable**, o factory que apunta clones a una address que es beacon-aware. Lo más limpio: **BeaconProxy** (o UUPS detrás de factory) si necesitás upgrade masivo. |
| **Impl UUPS detrás de cada clone** | Cada clone es un ERC1967/UUPS “barato” no es 1167 puro; otro diseño. |

Resumen mental:

```
1167 solo     = barato + lógica compartida + SIN upgrade fácil
1167 + faro   = barato + upgrade masivo (vía Beacon u homólogo)
UUPS/Transparent unitario = un proxy, upgrade individual
```

*(Detalle fino: un minimal proxy 1167 clásico embebe una address fija. Si esa address es un **contrato intermediario** que a su vez resuelve la lógica, podés componer patrones; lo habitual en docs OZ es: Clones hacia una impl, o BeaconProxy para upgrade conjunto.)*

### Piezas típicas en una factory

```
┌─────────────────────┐
│ Implementation      │  ← lógica (initialize, deposit, …)
└──────────┬──────────┘
           │ apuntada por
┌──────────▼──────────┐
│ Factory             │  ← clone() + initialize()
└──────────┬──────────┘
           │ crea
    ┌──────┴──────┐
    ▼             ▼
 Clone A       Clone B     ← storage A / storage B
```

### Gas / tamaño

| | Contrato completo | Minimal proxy |
|--|-------------------|---------------|
| Tamaño runtime | Miles de bytes | ~45 bytes |
| Coste deploy instancia | Alto | Muy bajo |
| Coste por call | Normal | + pequeño overhead `delegatecall` |

El ahorro está en **crear muchas instancias**, no en que cada call sea más barata que un contrato monolítico (el `delegatecall` tiene su costo).

### Riesgos / cuidados

| Riesgo | Detalle |
|--------|---------|
| **Impl no inicializable bien** | Clones tomables / estado basura |
| **Creer que es upgradeable** | 1167 puro no cambia de impl solo |
| **Storage layout** | Todos los clones comparten el layout de la misma lógica |
| **`selfdestruct` en la impl** | Históricamente podía romper clones; hoy `SELFDESTRUCT` está muy limitado — igual: no diseñes lógica destructiva en la impl compartida |
| **Factory maliciosa / salt** | CREATE2 mal usado → address collisions o front-run de salt |

### Minimal proxy vs Beacon vs UUPS (intuición)

| | Pregunta que responde |
|--|------------------------|
| **UUPS / Transparent** | “¿Cómo upgradear **este** sistema único?” |
| **Beacon** | “¿Cómo upgradear **muchas** instancias a la vez?” |
| **EIP-1167** | “¿Cómo **crear** muchas instancias baratas de la misma lógica?” |

Por eso se combinan: **1167 resuelve el deploy masivo; Beacon resuelve el upgrade masivo.**

### Analogía final

- Beacon = **faro** del pueblo (qué manual usar hoy).  
- Minimal proxy = **vaso descartable** con tu café: baratísimo de fabricar, cada uno con su contenido, todos siguen la misma receta impresa en el fondo del vaso.  
- Si la receta está **tatuada** en el vaso (1167 puro), no la cambiás.  
- Si el vaso dice “mirá el faro” (BeaconProxy), cambiás el faro y todos actualizan el manual.

---

## 1C. Diamond (EIP-2535) — explicación detallada

### ¿Qué es, en una frase?

Un **solo proxy** (el Diamond) cuya address es estable, pero la lógica no vive en un único contrato: vive repartida en varios contratos llamados **facets** (facetas).  
El Diamond tiene una tabla: **selector de función → address de la facet** que la implementa.

Analogía:

- **UUPS/Transparent** = un edificio con **un solo plano** de obra (una impl). Para renovar, cambiás el plano entero.  
- **Diamond** = un edificio con **muchas oficinas**. Renovás el piso de contabilidad sin tocar el de marketing. La dirección del edificio (proxy) no cambia.

### Problema que resuelve

1. **Límite de tamaño de contrato** (~24 KB de runtime bytecode en Ethereum). Un protocolo enorme no entra en un solo contrato.  
2. **Upgrades parciales**: no querés redesplegar / re-apuntar *toda* la lógica por un bug en una función.  
3. **Organización modular**: equipos o módulos (NFT, marketplace, royalties, admin) en contratos separados, misma address pública.

Diamond no es “para un Box con `store`/`retrieve`”. Es para sistemas **grandes y de larga vida**.

### Piezas del sistema

```
                    ┌─────────────────────────────────────┐
   Usuario ────────►│           Diamond (proxy)           │  address fija
                    │  fallback: selector → facet address │
                    │  storage del SISTEMA entero         │
                    └──────────────┬──────────────────────┘
                                   │ delegatecall
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
    FacetA (ERC20)          FacetB (Staking)         FacetC (Admin)
    transfer, approve       stake, unstake           pause, setFee
```

| Pieza | Rol |
|-------|-----|
| **Diamond** | Proxy + storage global. No concentra todo el negocio; enruta. |
| **Facet** | Contrato con un subconjunto de funciones. Se ejecuta vía `delegatecall` → escribe en storage del Diamond. |
| **DiamondCut** | Facet (o lógica) que **agrega / reemplaza / quita** selectores en la tabla. Es el “upgrade” del sistema. |
| **DiamondLoupe** | Facet de introspección: “¿qué facets hay?”, “¿qué selectores tiene esta facet?”. Estándar para exploradores/tools. |
| **Ownership / Access** | Quién puede hacer `diamondCut` (owner, multisig, DAO…). |

### Flujo de una llamada

```
1. Usuario llama Diamond.stake(100)
2. Fallback del Diamond:
   a) selector = bytes4(keccak256("stake(uint256)"))
   b) facet = selectorToFacet[selector]   →  FacetStaking
   c) delegatecall(FacetStaking, calldata)
3. stake() modifica storage en el Diamond (no en FacetStaking)
```

Igual que siempre: **estado en el proxy (Diamond)**; **código en la facet**.

### Flujo de upgrade: `diamondCut`

No hay un único `upgradeTo(newImpl)`. Hay un **corte** (cut) que modifica la tabla de selectores:

```solidity
// Idea conceptual (simplificada)
enum FacetCutAction { Add, Replace, Remove }

struct FacetCut {
    address facetAddress;
    FacetCutAction action;
    bytes4[] functionSelectors;
}

function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata calldataInit) external;
```

Ejemplos:

| Acción | Efecto |
|--------|--------|
| **Add** | Nuevos selectores → FacetNueva (feature nueva) |
| **Replace** | Mismos selectores → FacetV2 (bugfix de un módulo) |
| **Remove** | Selectores dejan de existir (deprecar API) |

Opcional: `init` + `calldata` = `delegatecall` de migración/setup justo después del cut (parecido a `upgradeToAndCall`).

### Storage: el punto más delicado

Como **todas** las facets comparten el storage del Diamond, el riesgo de colisión es alto si cada facet declara `uint256 x` en el slot 0.

Patrones habituales:

| Enfoque | Idea |
|---------|------|
| **Diamond Storage** | Cada módulo usa un struct en un slot namespaced (`keccak256("com.miapp.staking")`). |
| **AppStorage** | Un struct global único que todas las facets importan (orden fijo; frágil si reordenás). |
| **ERC-7201** | Namespaces de storage (como `Initializable` en OZ) |

Regla de oro: **nunca** asumir “mi variable está en el slot 0” en una facet suelta.

### Loupe (EIP-2535 introspection)

Funciones típicas (ideas):

- `facets()` — lista facets + selectores  
- `facetFunctionSelectors(address)`  
- `facetAddresses()`  
- `facetAddress(bytes4 selector)`  

Sirven para que wallets, exploradores y auditores **vean** la forma del diamante on-chain.

### Diamond vs UUPS vs Beacon (intuición)

| | Unidad de upgrade | Cuántas “impls” activas |
|--|-------------------|-------------------------|
| **UUPS / Transparent** | Toda la lógica | 1 |
| **Beacon** | Toda la lógica (para N proxies) | 1 compartida |
| **Diamond** | Por facet / por selector | Muchas a la vez |

```
¿Un solo producto, lógica mediana?     → UUPS / Transparent
¿Miles de instancias misma lógica?     → Beacon + clones
¿Un monstruo modular en una address?   → Diamond
```

### Ventajas (por qué existe)

1. **Escalá más allá de 24 KB** repartiendo código.  
2. **Upgrade quirúrgico** (solo un módulo).  
3. **Una sola address** para usuarios e integraciones.  
4. **Equipos en paralelo** sobre facets distintas (con disciplina de storage).  
5. **Remove** de funciones obsoletas sin redeploy del “todo”.

### Desventajas (por qué asusta)

| Contra | Detalle |
|--------|---------|
| **Complejidad** | Cuts, loupe, storage namespaces, permisos… curva alta |
| **Auditoría cara** | Más superficie; errores de storage son sutiles |
| **Selector clash** | Dos facets no pueden reclamar el mismo `bytes4` |
| **Gas** | Lookup de facet + `delegatecall` (aceptable, pero no “gratis”) |
| **Tooling** | Menos “baterías incluidas” que UUPS OZ para equipos chicos |
| **Gobernanza del cut** | Quien hace `diamondCut` es dios del protocolo |

### Riesgos típicos

1. **Storage collision** entre facets → corrupción de estado.  
2. **Cut malicioso / comprometido** → reemplazo de cualquier función.  
3. **Init calldata** peligroso en el cut (migración que pisa storage).  
4. **Facet olvidada** con selectores críticos (admin) mal protegidos.  
5. **Over-engineering**: usar Diamond donde bastaba UUPS.

### Anatomía mental de un `diamondCut` seguro

```
1. Multisig / Timelock propone cut
2. Review: qué selectors Add/Replace/Remove + nueva facet auditada
3. Verificar no hay clash de selectors
4. Verificar storage layout / namespace de la facet nueva
5. Ejecutar diamondCut (+ init de migración si aplica)
6. Loupe: confirmar tabla resultante
7. Tests e2e de módulos afectados
```

### ¿Downgrade en Diamond?

Sí, en el sentido de **Replace** selectores hacia una facet vieja (o Remove + Add).  
Más flexible que UUPS “todo o nada”, pero el storage sigue siendo el actual: no hay rewind mágico.

### Ejemplo de mapa de selectores (toy)

| Selector | Facet |
|----------|--------|
| `transfer(address,uint256)` | FacetERC20 |
| `stake(uint256)` | FacetStaking |
| `diamondCut(...)` | FacetCut |
| `facets()` | FacetLoupe |
| `pause()` | FacetAdmin |

El usuario siempre llama a **una** address: la del Diamond.

### Analogía final del Diamond

- Edificio = **Diamond** (dirección fija, sótano = storage).  
- Oficinas = **Facets** (código de cada área).  
- Directorio en recepción = **tabla selector → facet**.  
- Reforma de una oficina = **Replace** en `diamondCut`.  
- Ampliar un piso nuevo = **Add**.  
- Cerrar un área = **Remove**.  
- Plano del edificio para visitas = **Loupe**.

No es tocineta ni faro: es un **diamante tallado en caras**. Cada cara (facet) refleja una parte del protocolo; el diamante entero es lo que el mundo ve.

### ¿Entra en el módulo 11?

No (excluido a propósito en la planificación). UUPS + Transparent enseñan el núcleo `delegatecall` + storage. Diamond es el siguiente nivel de arquitectura modular cuando el sistema **no cabe** cómodo en una sola impl.

---

## 2. Tabla de patrones (explicación · usos · pros · contras)

### 2.1 Vista rápida

| Patrón | Una línea |
|--------|-----------|
| Contrato fijo (sin proxy) | Address = código = storage; no upgrade |
| ERC-1967 “simple” | Proxy + slot de impl; base de los demás |
| Transparent | Admin vs usuario en el proxy; upgrade vía ProxyAdmin |
| UUPS | Proxy mínimo; upgrade en la implementación |
| Beacon | Muchos proxies; una beacon dice la impl |
| Minimal proxy (EIP-1167) | Clones baratos a una impl (fija o vía beacon) |
| Diamond (EIP-2535) | Un proxy, muchas facetas por selector |
| Metamorphic / CREATE2 | Misma address, bytecode nuevo tras destroy |

---

### 2.2 Tabla extendida

#### Contrato fijo (sin proxy)

| | |
|--|--|
| **Explicación técnica** | Un solo bytecode en una address. Storage y lógica juntos. Sin `delegatecall` de routing. |
| **Usos (más extendido)** | Tokens “inmutables”, multisigs simples, scripts, demos, contratos que deben ser creíblemente no upgradeables. |
| **Ventajas** | Máxima simplicidad; fácil de auditar; sin riesgo de upgrade malicioso; gas predecible. |
| **Desventajas** | Bug o feature nueva ⇒ redeploy + migración (dolor social/técnico). |

#### ERC-1967 Proxy (base)

| | |
|--|--|
| **Explicación técnica** | Proxy con `fallback` → `delegatecall` a address en slot canónico `eip1967.proxy.implementation`. Evita colisión con storage de la lógica. |
| **Usos** | Cimiento de Transparent, UUPS y muchas libs (OZ). Rara vez se usa “pelado” en prod sin mecanismo de upgrade. |
| **Ventajas** | Estándar; tools/indexers conocen el slot; storage de negocio separado del puntero. |
| **Desventajas** | Solo es el transporte; falta definir *quién* puede cambiar el slot y cómo. |

#### Transparent Proxy

| | |
|--|--|
| **Explicación técnica** | Si `msg.sender == admin` → funciones de admin (upgrade). Si no → `delegatecall` a la impl. Suele ir con `ProxyAdmin` (Ownable2Step). En OZ v5 el admin suele ser immutable. |
| **Usos** | Protocolos con equipo/ops que upgradear sin mezclar selectores con usuarios; muchos proyectos “clásicos” OZ pre-UUPS-first. |
| **Ventajas** | Resuelve function clash; separación clara admin/usuario; modelo mental ops-friendly. |
| **Desventajas** | Proxy más pesado (check admin en cada call); deploy + ProxyAdmin; admin no debe usar el proxy como wallet de usuario. |

#### UUPS (ERC-1822)

| | |
|--|--|
| **Explicación técnica** | Proxy “tonto” (solo slot + `delegatecall`). `upgradeToAndCall` vive en la impl; `_authorizeUpgrade` + `proxiableUUID` evitan upgrades a lógica no-UUPS. |
| **Usos** | Estándar actual de muchos protocolos OZ v5; cuando querés proxy liviano y auth en la lógica. |
| **Ventajas** | Menos gas/código en el proxy; upgrade flexible; bien documentado. |
| **Desventajas** | Si upgradear a impl sin UUPS → brick; hay que cuidar auth en **cada** versión; clash de selectores posible (menos drama que Transparent, pero existe en diseño de API). |

#### Beacon Proxy

| | |
|--|--|
| **Explicación técnica** | Cada instancia guarda address del **beacon**. En runtime: `impl = beacon.implementation()` → `delegatecall(impl)`. Upgrade = `beacon.upgradeTo(newImpl)`. |
| **Usos** | Factories con muchas instancias (vaults, accounts, pools clones); “una lógica, N storages”. Muy visto con **clones**. |
| **Ventajas** | Upgrade masivo en 1 tx; deploy de instancias más barato en conjunto; DRY de lógica. |
| **Desventajas** | Un error de upgrade pega a todos; extra lectura al beacon por call; centralización fuerte en el owner del beacon. |

#### Minimal Proxy / Clones (EIP-1167)

| | |
|--|--|
| **Explicación técnica** | Bytecode mínimo (~45 bytes) que `delegatecall` a una implementación fija embebida (o patrón clone+beacon). `CREATE2` frecuente para addresses predecibles. |
| **Usos** | Wallets smart, vaults por usuario, Gnosis-style factories, cualquier “mucho de lo mismo”. |
| **Ventajas** | Deploy **muy** barato por instancia; escala a miles de contratos. |
| **Desventajas** | Clone puro a impl fija **no** upgradear solo; para upgrade masivo se combina con **Beacon**. Init hay que cuidarlo (initializer, no constructor útil). |

#### Diamond (EIP-2535)

| | |
|--|--|
| **Explicación técnica** | Un proxy (Diamond) mantiene `selector → facet`. Fallback hace `delegatecall` a la facet. Upgrades vía `diamondCut` (Add/Replace/Remove). Storage compartido con namespaces (Diamond Storage / AppStorage). Loupe para introspección. |
| **Usos** | Sistemas enormes modulares (juegos on-chain, protocolos con muchas features); menos “DeFi simple” que UUPS. |
| **Ventajas** | Escala de código sin un único contrato gigante; upgrades parciales por facet; organización por módulos. |
| **Desventajas** | Complejidad alta (storage diamond, clashes de selectores, tooling); auditorías más caras; curva de aprendizaje fuerte. |

#### Metamorphic / CREATE2 + selfdestruct (históricos / nicho)

| | |
|--|--|
| **Explicación técnica** | Misma address vía `CREATE2`; se destruye el código y se vuelve a desplegar otro bytecode en la misma address. Tras cambios de red (deprecación de `SELFDESTRUCT` útil), cada vez menos viable. |
| **Usos** | Experimentos, algunos factories viejos; **no** es el path recomendado hoy. |
| **Ventajas** | Address idéntica con bytecode nuevo (en teoría). |
| **Desventajas** | Frágil, peligroso, mal visto; storage no “viaja” como en proxy; restricciones modernas lo limitan. |

---

## 3. ¿Cuál elegir? (mapa corto)

```
¿Necesitás upgrade?
  NO  → Contrato fijo
  SÍ  → ¿Muchas instancias misma lógica?
           SÍ  → Beacon (+ clones EIP-1167)
           NO  → ¿Admin ops separado / miedo a clash?
                    SÍ  → Transparent
                    NO  → UUPS (default moderno “un solo proxy”)
         ¿Sistema enorme modular?
           → Evaluar Diamond (costo alto)
```

---

## 4. Beacon y este módulo (11)

El módulo 11 implementa **UUPS + Transparent** (un proxy, una lógica, upgrade individual).

**Beacon** sería el siguiente salto natural si el producto fuera:

> “factory de 500 boxes/vaults; quiero upgradear la lógica de todos de una vez”.

No está en el alcance v1 (ver `planificacion.md`: Beacon/Diamond excluidos a propósito).

---

## 5. Analogía final (panceta incluida)

- **UUPS / Transparent:** cada casa tiene su propio plano en el cajón; para renovar todas las casas, visitás casa por casa.  
- **Beacon:** hay un **faro** en el pueblo. Todas las casas miran el faro para saber qué plano usar. Movés el faro → todas renuevan a la vez.  
- **Clones:** casas prefabricadas baratas que miran el mismo plano (y a menudo el mismo faro).  
- **Diamond:** un edificio con muchas oficinas (facetas); renovás piso por piso.

La “tocineta” es el faro: no guarda tus muebles (storage), solo dice **qué manual de instrucciones** (implementation) hay que seguir hoy.
