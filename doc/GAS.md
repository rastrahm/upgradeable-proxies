# Optimización de gas — Upgradeable Proxies (UUPS & Transparent)

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract ProxyGasTest --gas-report
forge snapshot --match-contract ProxyGasTest
```

**Fecha baseline:** 2026-09-08 (Fase 6)  
**Snapshot:** `.gas-snapshot` (`test/gas/Proxy.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`

---

## Comparativa suite (antes Fase 6 → después)

Mediciones de tests representativos del hot path (gas report Foundry del test completo):

| Test / path | Antes (Fase 5) | Después (Fase 6) | Δ |
|-------------|----------------|------------------|---|
| `TransparentProxy.test_UserCallsDelegateToImplementation` | 46 199 | **43 691** | **−2 508** |
| `TransparentProxy.test_RevertWhen_AdminCallsUserFunction` | 12 907 | **10 774** | **−2 133** |
| `ERC1967Proxy.test_DelegatecallWritesStorageOnProxyNotOnLogic` | 43 641 | **43 349** | −292 |
| `UpgradeE2E.test_E2E_Transparent_*` (tx completa) | 1 154 138 | **987 361** | **−166 777** |
| `BoxUpgrade.test_UpgradeV1ToV2_*` | 858 607 | **827 640** | **−30 967** |

> El mayor ahorro en E2E Transparent viene de **bytecode más chico** (admin `immutable`, sin `changeAdmin`) + menos SLOAD en routing.

---

## Benchmarks `ProxyGasTest` (post-opt)

| Test | Gas (approx.) | Notas |
|------|---------------|--------|
| `testGas_Transparent_setValue` | ~32 639 | Usuario → fallback → `setValue` |
| `testGas_Transparent_value` | ~12 604 | View vía proxy |
| `testGas_UUPS_store` | ~32 780 | Box vía ERC1967 |
| `testGas_UUPS_retrieve` | ~12 189 | View |
| `testGas_Transparent_upgradeAndCall` | ~198 629 | Incluye deploy V2 en el test |
| `testGas_UUPS_upgradeToV2` | ~810 474 | Incluye deploy BoxV2 + `initializeV2` |

### Gas-report (medianas de funciones en proxy)

| Función | Contrato | Median / Min | Notas |
|---------|----------|--------------|-------|
| `fallback` | TransparentProxy | min **7 185** | Path admin/usuario |
| `fallback` | ERC1967Proxy | min **7 119** | Solo delegatecall |
| `upgradeAndCall` | ProxyAdmin | **37 032** | Sin coste de nueva impl |
| Deploy | ERC1967Proxy | ~214 k | Runtime priorizado |
| Deploy | TransparentProxy | ~369 k | + immutable admin |

---

## Optimizaciones aplicadas (Fase 6)

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| **Admin `immutable`** | `TransparentProxy` | Elimina SLOAD del admin en **cada** call de usuario |
| **Slot EIP-1967 admin solo en constructor** | `TransparentProxy` | Compatibilidad `eth_getStorageAt` sin coste runtime |
| **Sin `changeAdmin` on-proxy** | Transparent / ProxyAdmin | Menos código; rotación vía `Ownable2Step` del admin |
| **Sin `extcodesize` en hot path** | `ERC1967Proxy._fallback` | Validación de código solo en `_setImplementation` |
| **Slots EIP-1967 precomputados** | Proxy / UUPS | Sin `keccak256` en runtime |
| **`delegatecall` en assembly** | `_delegate` / `_delegateCall` | Menos overhead que high-level + returndata |
| **`bytes calldata` en upgrades** | `UUPSUpgradeable` / `ProxyAdmin` | Evita copia memory del payload |
| **`extcodesize` en assembly** | set/upgrade | Un check cubre `address(0)` y EOA |
| **Cache `owner` en `_authorizeUpgrade`** | BoxV1 / BoxV2 | 1 SLOAD explícito |
| **`optimizer_runs = 10_000`** | `foundry.toml` | Inlining agresivo en fallback |

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| Admin immutable (no `changeAdmin` en proxy) | Igual que OZ v5 Transparent; rotar = ownership del `ProxyAdmin` |
| Sin `extcodesize` por call | Upgrade path ya valida código; hot path asume slot sano |
| Deploy algo más/menos según contrato | Priorizamos **runtime** de `fallback` / `store` |
| String `version()` / `UPGRADE_INTERFACE_VERSION` | API clara > micro-ahorro de deploy |

---

## Relación con seguridad

Las optimizaciones **no** debilitan auth ni layout:

- Transparent: admin sigue siendo solo `ProxyAdmin`; usuario no escribe el slot impl.
- UUPS: `onlyProxy` + `proxiableUUID` + `_authorizeUpgrade` intactos.
- Initializers / `__gap` sin cambios de offsets.
- Ver [`SWC-AUDIT.md`](./SWC-AUDIT.md) y [`storage-layout.md`](./storage-layout.md).
