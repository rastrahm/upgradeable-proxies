# Storage slots — why not use slot 0 (and how everything is laid out)

> 🌐 **English** · [Español](./STORAGE-SLOTS-ES.md) · [Index](../README.md)

The statement:

> **Do not store `address implementation` in the proxy's slot 0**

is not a stylistic quirk. It exists to prevent the **logic pointer** and the **business state** from stepping on the same drawer.

---

## 1. A single "chest of drawers": the proxy's

When you do:

```text
user → Proxy.fallback → delegatecall(Implementation)
```

the EVM executes the Implementation's **code**, but reads and writes the **Proxy's storage**.

```text
┌─────────────────────────────────────────┐
│  PROXY address                          │
│  storage[0], storage[1], … storage[2^256)│
│                                         │
│  ← ALL visible state lives here         │
└─────────────────────────────────────────┘
         ▲
         │  delegatecall uses THIS storage
         │
┌────────┴────────┐
│ Implementation  │  only provides bytecode
│ (another addr)  │  its "own" storage is barely used
└─────────────────┘
```

The deployed Implementation also has storage at *its* address, but in normal use through the proxy **it is not the one that matters**. What matters is how the logic **numbers** the slots when it runs in the proxy's context.

---

## 2. How Solidity assigns slots (normal layout)

In a "flat" contract, state variables are stacked starting from **slot 0**:

```solidity
contract Box {
    address public owner;  // slot 0
    uint256 public value;  // slot 1
    string  public label;  // slot 2 (header; long data at keccak)
}
```

| Variable | Slot |
|----------|------|
| `owner` | 0 |
| `value` | 1 |
| `label` | 2 |
| next | 3… |

Quick rules:

- Each slot = 32 bytes.
- Small types can be **packed** into the same slot (`uint128` + `uint128`, etc.).
- Dynamic `mapping` / `string` / `bytes`: the "base" slot stores a pointer/length; the data goes to `keccak256(slot)` or other formulas.
- Inheritance: first the slots of the base contracts (in linearized inheritance order), then the child's — except for namespaced storage (ERC-7201).

---

## 3. The collision if the proxy uses slot 0

### Bad design (collision)

```solidity
// ❌ Naive proxy
contract BadProxy {
    address public implementation; // Solidity places it in slot 0
    // fallback → delegatecall(implementation)
}

contract Box {
    address public owner;  // the logic BELIEVES owner is in slot 0
    uint256 public value;  // slot 1
}
```

What happens when calling `Box(proxy).initialize(alice)` via `delegatecall`:

```text
PROXY storage
─────────────────
slot 0:  before = address(Implementation)  ← the proxy needs it for routing
         after  = alice                    ← the logic wrote "owner"
slot 1:  value = ...
```

You have just **overwritten the implementation pointer** with the owner's address.

Possible effects:

1. The next `delegatecall` goes to `alice` (EOA) → boom / bricked.  
2. Or you interpret garbage as code.  
3. Or `owner` and `implementation` corrupt each other depending on the order of reads.

That is a **storage collision**: two different meanings for the same index.

### Good design (EIP-1967)

The proxy does **not** declare `address implementation` as a normal variable in slot 0.  
It stores the pointer in a **distant** slot, computed so it does not collide with layouts that start at 0:

```text
IMPLEMENTATION_SLOT =
  bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
  = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

```text
PROXY storage (good)
─────────────────────────
slot 0:     owner          ← business (Box)
slot 1:     value          ← business
slot 2..51: __gap / label  ← business
...
slot 0x3608…82bbc:  address(Implementation)  ← only the proxy looks at this
```

Box's logic **never** writes that high slot (barring a bug or malicious assembly).  
The proxy **only** reads/writes that slot when upgrading or routing.

---

## 4. Full map — what is in the proxy's storage (module 11)

Think of three "layers" in the **same** proxy chest of drawers:

### Layer A — Business (Box layout, sequential)

As in `forge inspect` / [`storage-layout-EN.md`](./storage-layout-EN.md):

**BoxV1**

| Slot | Content |
|------|-----------|
| 0 | `owner` |
| 1 | `value` |
| 2 … 51 | `__gap[50]` (reserve) |

**BoxV2**

| Slot | Content |
|------|-----------|
| 0 | `owner` (same) |
| 1 | `value` (same) |
| 2 | `label` (new; consumes 1 from the gap) |
| 3 … 51 | `__gap[49]` |

```text
V1:  [0 owner][1 value][2 ──────── gap 50 ──────── 51]
V2:  [0 owner][1 value][2 label][3 ──── gap 49 ──── 51]
```

### Layer B — Proxy metadata (EIP-1967, "odd" slots)

| Name | Slot (constant) | Who uses it |
|--------|------------------|--------------|
| Implementation | `0x360894a1…d382bbc` | ERC1967 / UUPS / Transparent |
| Admin | `0xb5312768…5d6103` | Transparent (written at deploy; routing may use immutable) |
| Beacon | `0xa3f0ad74…4b780` | Beacon pattern only |

Formulas:

```text
impl  = keccak256("eip1967.proxy.implementation") - 1
admin = keccak256("eip1967.proxy.admin") - 1
beacon= keccak256("eip1967.proxy.beacon") - 1
```

They are in a region of the `2^256` space that a normal Solidity layout (0, 1, 2…) is **practically impossible** to reach by accident.

### Layer C — Initializable (ERC-7201, another namespace)

`Initializable` does **not** put `_initialized` in slot 0 (if it did, it would collide with `owner`).

It uses a namespaced slot, e.g.:

```text
INITIALIZABLE_STORAGE =
  0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00
```

There it stores something like:

| Field | Use |
|-------|-----|
| `_initialized` | init version (1, 2, … or max = disabled) |
| `_initializing` | init reentrancy flag |

That is why `forge inspect BoxV1` shows `owner`/`value`/`__gap` and does **not** list Initializable's storage in the 0…N sequence: it lives in another "department".

### Immutables (do not occupy proxy storage)

In UUPS, `address private immutable __self` is stored in the Implementation's **bytecode**, not in a proxy slot.  
It is used to know "am I in a delegatecall, or was the impl called directly?".

---

## 5. Unified drawing of the PROXY storage

```text
Low indices (Box business)
────────────────────────────────────────
  0   owner
  1   value
  2   label (V2 only) / gap start (V1)
  3…51 remaining gap
  52…  (free for the future if you follow the gap)

"Astronomical" indices (proxy / lib metadata)
────────────────────────────────────────
  0xf0c57e16…9c6a00     Initializable (ERC-7201)
  0x360894a1…d382bbc    EIP-1967 implementation
  0xb5312768…5d6103     EIP-1967 admin (Transparent)
  0xa3f0ad74…4b780      EIP-1967 beacon (if you use Beacon)

Remaining space
────────────────────────────────────────
  2^256 slots in total — the normal layout barely approaches the EIP-1967 ones
```

---

## 6. What about the Implementation's storage at its own address?

When doing `new BoxV1()`:

- The constructor runs → `_disableInitializers()` writes to the storage of **BoxV1's address**.
- That storage is **not** the proxy's.

Therefore:

- `boxV1Impl.owner()` is usually `0` (it was never usefully initialized there).  
- `Box(proxy).owner()` holds the real value.

Module tests: "impl storage must stay empty / unchanged" = proving that the state ended up in the proxy.

---

## 7. Why the `__gap`

If tomorrow BoxV3 needs `uint256 fee`:

- Without a gap: you would have to add `fee` **after** everything that exists; if someone inserts in the middle, the layout shifts.  
- With a gap: you "consume" one slot from the gap (`50 → 49`) and the rest of the V1/V2 offsets stay the same.

The gap is **not** for the EIP-1967 pointer (that one is already far away). It is for **evolving the business layout** without collisions between versions.

---

## 8. Mental checklist

1. `delegatecall` ⇒ a single chest of drawers = the **proxy's** storage.  
2. The business layout starts at **0, 1, 2…**  
3. That is why the proxy **cannot** put `implementation` at 0.  
4. EIP-1967 = "hidden drawer" for the pointer (and admin/beacon).  
5. Initializable = another hidden drawer (ERC-7201).  
6. Gaps = reserve in the low region for business upgrades.  
7. "Bad" unupgradeable = two meanings in the same slot.

---

## 9. How to see it yourself

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge inspect BoxV1 storage-layout
forge inspect BoxV2 storage-layout

# EIP-1967 constants (already fixed in the code / standard)
# impl:  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
# admin: 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
```

In tests: `vm.load(proxy, IMPLEMENTATION_SLOT)` vs `vm.load(proxy, bytes32(uint256(0)))` — the first is the impl; the second is `owner` (packed into 20 bytes of the slot).

---

*Related: [`storage-layout-EN.md`](./storage-layout-EN.md) (Box V1/V2) · [`ENTENDER-EL-MODULO-EN.md`](./ENTENDER-EL-MODULO-EN.md) · [`PATRONES-PROXY-EN.md`](./PATRONES-PROXY-EN.md)*
