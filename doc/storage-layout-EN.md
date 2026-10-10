# Storage layout — BoxV1 / BoxV2

> 🌐 **English** · [Español](./storage-layout-ES.md) · [Index](../README.md)

Phase 4 document. Generated with:

```bash
forge inspect BoxV1 storage-layout
forge inspect BoxV2 storage-layout
```

`Initializable` uses **ERC-7201** namespaced storage (it does not appear in the sequential layout).  
`UUPSUpgradeable` only contributes `immutable` values (no storage slots).

---

## BoxV1

| Label | Slot | Type | Bytes |
|-------|------|------|-------|
| `owner` | 0 | `address` | 20 |
| `value` | 1 | `uint256` | 32 |
| `__gap` | 2 … 51 | `uint256[50]` | 1600 |

**End of the reserved state block:** slot **51**.

---

## BoxV2

| Label | Slot | Type | Bytes |
|-------|------|------|-------|
| `owner` | 0 | `address` | 20 |
| `value` | 1 | `uint256` | 32 |
| `label` | 2 | `string` | 32 (header) |
| `__gap` | 3 … 51 | `uint256[49]` | 1568 |

**End of the reserved state block:** slot **51** (same as V1).

---

## V1 → V2 compatibility

| Check | Result |
|-------|-----------|
| `owner` stays in slot 0 | ✅ |
| `value` stays in slot 1 | ✅ |
| New var `label` uses the first slot of the former `__gap` (slot 2) | ✅ |
| `__gap` 50 → 49 (1 slot is “consumed”) | ✅ |
| No V1 slots are reordered or reused with a different meaning | ✅ |

```
V1:  [owner][value][-------- __gap[50] --------]
V2:  [owner][value][label][---- __gap[49] -----]
      slot0  slot1  slot2   slots 3..51
```

---

## Operating rule

1. Never insert variables **before** existing ones.
2. When adding N state slots, reduce `__gap` by N.
3. After the design, validate with `forge inspect` and a persistence test (see `test/BoxUpgrade.t.sol`).
