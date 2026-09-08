# Storage layout — BoxV1 / BoxV2

Documento de Fase 4. Generado con:

```bash
forge inspect BoxV1 storage-layout
forge inspect BoxV2 storage-layout
```

`Initializable` usa storage namespaced **ERC-7201** (no aparece en el layout secuencial).  
`UUPSUpgradeable` solo aporta `immutable` (sin slots de storage).

---

## BoxV1

| Label | Slot | Tipo | Bytes |
|-------|------|------|-------|
| `owner` | 0 | `address` | 20 |
| `value` | 1 | `uint256` | 32 |
| `__gap` | 2 … 51 | `uint256[50]` | 1600 |

**Fin del bloque de estado reservado:** slot **51**.

---

## BoxV2

| Label | Slot | Tipo | Bytes |
|-------|------|------|-------|
| `owner` | 0 | `address` | 20 |
| `value` | 1 | `uint256` | 32 |
| `label` | 2 | `string` | 32 (cabecera) |
| `__gap` | 3 … 51 | `uint256[49]` | 1568 |

**Fin del bloque de estado reservado:** slot **51** (igual que V1).

---

## Compatibilidad V1 → V2

| Check | Resultado |
|-------|-----------|
| `owner` permanece en slot 0 | ✅ |
| `value` permanece en slot 1 | ✅ |
| Nueva var `label` usa el primer slot del antiguo `__gap` (slot 2) | ✅ |
| `__gap` 50 → 49 (se “consume” 1 slot) | ✅ |
| No se reordenan ni se reutilizan slots de V1 con otro significado | ✅ |

```
V1:  [owner][value][-------- __gap[50] --------]
V2:  [owner][value][label][---- __gap[49] -----]
      slot0  slot1  slot2   slots 3..51
```

---

## Regla operativa

1. Nunca insertar variables **antes** de las existentes.
2. Al añadir N slots de estado, reducir `__gap` en N.
3. Tras el diseño, validar con `forge inspect` y un test de persistencia (ver `test/BoxUpgrade.t.sol`).
