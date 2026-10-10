# Gas Optimization — Upgradeable Proxies (UUPS & Transparent)

> 🌐 **English** · [Español](./GAS-ES.md) · [Index](../README.md)

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract ProxyGasTest --gas-report
forge snapshot --match-contract ProxyGasTest
```

**Baseline date:** 2026-09-08 (Phase 6)  
**Snapshot:** `.gas-snapshot` (`test/gas/Proxy.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`

---

## Suite comparison (before Phase 6 → after)

Measurements of representative hot-path tests (Foundry gas report for the full test):

| Test / path | Before (Phase 5) | After (Phase 6) | Δ |
|-------------|----------------|------------------|---|
| `TransparentProxy.test_UserCallsDelegateToImplementation` | 46 199 | **43 691** | **−2 508** |
| `TransparentProxy.test_RevertWhen_AdminCallsUserFunction` | 12 907 | **10 774** | **−2 133** |
| `ERC1967Proxy.test_DelegatecallWritesStorageOnProxyNotOnLogic` | 43 641 | **43 349** | −292 |
| `UpgradeE2E.test_E2E_Transparent_*` (full tx) | 1 154 138 | **987 361** | **−166 777** |
| `BoxUpgrade.test_UpgradeV1ToV2_*` | 858 607 | **827 640** | **−30 967** |

> The largest saving in E2E Transparent comes from **smaller bytecode** (`immutable` admin, no `changeAdmin`) + fewer SLOADs in routing.

---

## `ProxyGasTest` benchmarks (post-opt)

| Test | Gas (approx.) | Notes |
|------|---------------|--------|
| `testGas_Transparent_setValue` | ~32 639 | User → fallback → `setValue` |
| `testGas_Transparent_value` | ~12 604 | View via proxy |
| `testGas_UUPS_store` | ~32 780 | Box via ERC1967 |
| `testGas_UUPS_retrieve` | ~12 189 | View |
| `testGas_Transparent_upgradeAndCall` | ~198 629 | Includes V2 deploy in the test |
| `testGas_UUPS_upgradeToV2` | ~810 474 | Includes BoxV2 deploy + `initializeV2` |

### Gas report (medians of functions on the proxy)

| Function | Contract | Median / Min | Notes |
|---------|----------|--------------|-------|
| `fallback` | TransparentProxy | min **7 185** | Admin/user path |
| `fallback` | ERC1967Proxy | min **7 119** | Delegatecall only |
| `upgradeAndCall` | ProxyAdmin | **37 032** | Excludes new impl cost |
| Deploy | ERC1967Proxy | ~214 k | Runtime prioritized |
| Deploy | TransparentProxy | ~369 k | + immutable admin |

---

## Applied optimizations (Phase 6)

| Technique | Where | Effect |
|---------|-------|--------|
| **`immutable` admin** | `TransparentProxy` | Removes the admin SLOAD on **every** user call |
| **EIP-1967 admin slot only in constructor** | `TransparentProxy` | `eth_getStorageAt` compatibility with no runtime cost |
| **No on-proxy `changeAdmin`** | Transparent / ProxyAdmin | Less code; rotation via the admin's `Ownable2Step` |
| **No `extcodesize` on the hot path** | `ERC1967Proxy._fallback` | Code validation only in `_setImplementation` |
| **Precomputed EIP-1967 slots** | Proxy / UUPS | No `keccak256` at runtime |
| **`delegatecall` in assembly** | `_delegate` / `_delegateCall` | Less overhead than high-level + returndata |
| **`bytes calldata` in upgrades** | `UUPSUpgradeable` / `ProxyAdmin` | Avoids copying the payload to memory |
| **`extcodesize` in assembly** | set/upgrade | A single check covers `address(0)` and EOAs |
| **Cache `owner` in `_authorizeUpgrade`** | BoxV1 / BoxV2 | 1 explicit SLOAD |
| **`optimizer_runs = 10_000`** | `foundry.toml` | Aggressive inlining in fallback |

---

## Accepted tradeoffs

| Decision | Why |
|----------|---------|
| Immutable admin (no `changeAdmin` on the proxy) | Same as OZ v5 Transparent; rotating = ownership of the `ProxyAdmin` |
| No `extcodesize` per call | The upgrade path already validates code; the hot path assumes a sound slot |
| Somewhat more/less deploy gas depending on the contract | We prioritize **runtime** of `fallback` / `store` |
| String `version()` / `UPGRADE_INTERFACE_VERSION` | Clear API > deploy micro-savings |

---

## Relationship with security

The optimizations do **not** weaken auth or layout:

- Transparent: the admin is still only the `ProxyAdmin`; users cannot write the impl slot.
- UUPS: `onlyProxy` + `proxiableUUID` + `_authorizeUpgrade` intact.
- Initializers / `__gap` with no offset changes.
- See [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) and [`storage-layout-EN.md`](./storage-layout-EN.md).
