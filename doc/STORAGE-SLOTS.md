# Storage slots — por qué no usar el slot 0 (y cómo se reparte todo)

La afirmación:

> **No guardar `address implementation` en el slot 0 del proxy**

no es una manía de estilo. Es para evitar que el **puntero de lógica** y el **estado de negocio** se pisen el mismo cajón.

---

## 1. Una sola “cajonera”: la del proxy

Cuando hacés:

```text
usuario → Proxy.fallback → delegatecall(Implementation)
```

la EVM ejecuta el **código** de la Implementation, pero lee y escribe el **storage del Proxy**.

```text
┌─────────────────────────────────────────┐
│  Address del PROXY                      │
│  storage[0], storage[1], … storage[2^256)│
│                                         │
│  ← aquí vive TODO el estado visible     │
└─────────────────────────────────────────┘
         ▲
         │  delegatecall usa ESTE storage
         │
┌────────┴────────┐
│ Implementation  │  solo aporta bytecode
│ (otra address)  │  su storage “propio” casi no se usa
└─────────────────┘
```

La Implementation desplegada también tiene storage en *su* address, pero en uso normal vía proxy **no es el que importa**. Lo que importa es cómo la lógica **numera** los slots cuando corre en el contexto del proxy.

---

## 2. Cómo Solidity asigna slots (layout normal)

En un contrato “plano”, las variables de estado se apilan desde el **slot 0**:

```solidity
contract Box {
    address public owner;  // slot 0
    uint256 public value;  // slot 1
    string  public label;  // slot 2 (cabecera; datos largos en keccak)
}
```

| Variable | Slot |
|----------|------|
| `owner` | 0 |
| `value` | 1 |
| `label` | 2 |
| siguiente | 3… |

Reglas rápidas:

- Cada slot = 32 bytes.
- Tipos chicos pueden **empaquetarse** en el mismo slot (`uint128` + `uint128`, etc.).
- `mapping` / `string` / `bytes` dinámicos: el slot “base” guarda un puntero/longitud; los datos van a `keccak256(slot)` u otras fórmulas.
- Herencia: primero los slots de los contratos base (en orden de herencia linearizada), luego los del hijo — salvo storage namespaced (ERC-7201).

---

## 3. El choque si el proxy usa el slot 0

### Diseño malo (colisión)

```solidity
// ❌ Proxy ingenuo
contract BadProxy {
    address public implementation; // Solidity lo pone en slot 0
    // fallback → delegatecall(implementation)
}

contract Box {
    address public owner;  // la lógica CREE que owner está en slot 0
    uint256 public value;  // slot 1
}
```

Qué pasa al hacer `Box(proxy).initialize(alice)` vía `delegatecall`:

```text
Storage del PROXY
─────────────────
slot 0:  antes = address(Implementation)   ← el proxy lo necesita para enrutar
         después = alice                   ← la lógica escribió "owner"
slot 1:  value = ...
```

Acabás de **sobrescribir el puntero** de implementación con la address del owner.

Efectos posibles:

1. El próximo `delegatecall` va a `alice` (EOA) → boom / bricked.  
2. O interpretás basura como código.  
3. O `owner` y `implementation` se corrompen mutuamente según el orden de lecturas.

Eso es una **colisión de storage**: dos significados distintos para el mismo índice.

### Diseño bueno (EIP-1967)

El proxy **no** declara `address implementation` como variable normal en slot 0.  
Guarda el puntero en un slot **alejado**, calculado para que no choque con layouts que empiezan en 0:

```text
IMPLEMENTATION_SLOT =
  bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
  = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

```text
Storage del PROXY (bueno)
─────────────────────────
slot 0:     owner          ← negocio (Box)
slot 1:     value          ← negocio
slot 2..51: __gap / label  ← negocio
...
slot 0x3608…82bbc:  address(Implementation)  ← solo el proxy mira esto
```

La lógica de Box **nunca** escribe ese slot alto (salvo bug o assembly malicioso).  
El proxy **solo** lee/escribe ese slot al upgradear o al enrutar.

---

## 4. Mapa completo — qué hay en el storage del proxy (módulo 11)

Pensá tres “capas” en la **misma** cajonera del proxy:

### Capa A — Negocio (layout de Box, secuencial)

Como en `forge inspect` / [`storage-layout.md`](./storage-layout.md):

**BoxV1**

| Slot | Contenido |
|------|-----------|
| 0 | `owner` |
| 1 | `value` |
| 2 … 51 | `__gap[50]` (reserva) |

**BoxV2**

| Slot | Contenido |
|------|-----------|
| 0 | `owner` (igual) |
| 1 | `value` (igual) |
| 2 | `label` (nuevo; come 1 del gap) |
| 3 … 51 | `__gap[49]` |

```text
V1:  [0 owner][1 value][2 ──────── gap 50 ──────── 51]
V2:  [0 owner][1 value][2 label][3 ──── gap 49 ──── 51]
```

### Capa B — Metadatos del proxy (EIP-1967, slots “raros”)

| Nombre | Slot (constante) | Quién lo usa |
|--------|------------------|--------------|
| Implementation | `0x360894a1…d382bbc` | ERC1967 / UUPS / Transparent |
| Admin | `0xb5312768…5d6103` | Transparent (escrito al deploy; routing puede usar immutable) |
| Beacon | `0xa3f0ad74…4b780` | Solo patrón Beacon |

Fórmulas:

```text
impl  = keccak256("eip1967.proxy.implementation") - 1
admin = keccak256("eip1967.proxy.admin") - 1
beacon= keccak256("eip1967.proxy.beacon") - 1
```

Están en una zona del espacio `2^256` donde es **prácticamente imposible** que un layout Solidity normal (0, 1, 2…) llegue sin querer.

### Capa C — Initializable (ERC-7201, otro namespace)

`Initializable` **no** pone `_initialized` en el slot 0 (si lo hiciera, chocaría con `owner`).

Usa un slot namespaced, p. ej.:

```text
INITIALIZABLE_STORAGE =
  0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00
```

Ahí guarda algo como:

| Campo | Uso |
|-------|-----|
| `_initialized` | versión de init (1, 2, … o max = disabled) |
| `_initializing` | flag reentrancy de init |

Por eso `forge inspect BoxV1` muestra `owner`/`value`/`__gap` y **no** lista el storage de Initializable en la cola 0…N: vive en otro “departamento”.

### Immutables (no ocupan storage del proxy)

En UUPS, `address private immutable __self` se guarda en el **bytecode** de la Implementation, no en un slot del proxy.  
Sirve para saber “¿estoy en delegatecall o llamaron a la impl directa?”.

---

## 5. Dibujo unificado del storage del PROXY

```text
Índice bajo (negocio Box)
────────────────────────────────────────
  0   owner
  1   value
  2   label (solo V2) / inicio gap (V1)
  3…51 gap restante
  52…  (libre para futuro si seguís el gap)

Índices “astronómicos” (metadatos proxy / libs)
────────────────────────────────────────
  0xf0c57e16…9c6a00     Initializable (ERC-7201)
  0x360894a1…d382bbc    EIP-1967 implementation
  0xb5312768…5d6103     EIP-1967 admin (Transparent)
  0xa3f0ad74…4b780      EIP-1967 beacon (si usás Beacon)

Espacio restante
────────────────────────────────────────
  2^256 slots en total — el layout normal casi no se acerca a los EIP-1967
```

---

## 6. ¿Y el storage de la Implementation en su propia address?

Al hacer `new BoxV1()`:

- Corre el constructor → `_disableInitializers()` escribe en el storage de **la address de BoxV1**.
- Ese storage **no** es el del proxy.

Por eso:

- `boxV1Impl.owner()` suele ser `0` (nunca se inicializó ahí de forma útil).  
- `Box(proxy).owner()` tiene el valor real.

Tests del módulo: “impl storage must stay empty / unchanged” = demostrar que el estado quedó en el proxy.

---

## 7. Por qué el `__gap`

Si mañana BoxV3 necesita `uint256 fee`:

- Sin gap: tendrías que agregar `fee` **después** de todo lo existente; si alguien inserta en el medio, corre el layout.  
- Con gap: “comés” un slot del gap (`50 → 49`) y el resto de offsets de V1/V2 se mantienen.

El gap **no** es para el puntero EIP-1967 (ese ya está lejos). Es para **evolucionar el layout de negocio** sin colisiones entre versiones.

---

## 8. Checklist mental

1. `delegatecall` ⇒ una sola cajonera = storage del **proxy**.  
2. Layout de negocio empieza en **0, 1, 2…**  
3. Por eso el proxy **no** puede poner `implementation` en 0.  
4. EIP-1967 = “cajón escondido” para el puntero (y admin/beacon).  
5. Initializable = otro cajón escondido (ERC-7201).  
6. Gaps = reserva en la zona baja para upgrades de negocio.  
7. Unupgradeable “malo” = dos significados en el mismo slot.

---

## 9. Cómo verlo vos mismo

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge inspect BoxV1 storage-layout
forge inspect BoxV2 storage-layout

# Constantes EIP-1967 (ya fijas en el código / estándar)
# impl:  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
# admin: 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
```

En tests: `vm.load(proxy, IMPLEMENTATION_SLOT)` vs `vm.load(proxy, bytes32(uint256(0)))` — el primero es la impl; el segundo es `owner` (empaquetado en 20 bytes del slot).

---

*Relacionado: [`storage-layout.md`](./storage-layout.md) (Box V1/V2) · [`ENTENDER-EL-MODULO.md`](./ENTENDER-EL-MODULO.md) · [`PATRONES-PROXY.md`](./PATRONES-PROXY.md)*
