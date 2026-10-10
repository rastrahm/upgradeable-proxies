# SWC Audit — Upgradeable Proxies (UUPS & Transparent)

> 🌐 **English** · [Español](./SWC-AUDIT-ES.md) · [Index](../README.md)

Verification of EIP-1967 proxies, Transparent/`ProxyAdmin`, UUPS/`Initializable` and Box V1/V2 against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and the monorepo principles (custom errors, fixed pragma, access control, storage gaps).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts (prod / core):**  
`src/proxy/ERC1967Proxy.sol`, `src/proxy/TransparentProxy.sol`, `src/proxy/ProxyAdmin.sol`,  
`src/uups/UUPSUpgradeable.sol`, `src/utils/Initializable.sol`,  
`src/implementations/BoxV1.sol`, `src/implementations/BoxV2.sol` (+ interfaces / errors)

**Mocks (outside prod):** `src/mocks/*`  
**Date:** 2026-09-08  
**Test reference:** `test/ERC1967Proxy.t.sol`, `test/TransparentProxy.t.sol`, `test/UUPS.t.sol`, `test/BoxUpgrade.t.sol`, `test/UpgradeE2E.t.sol`, `test/fuzz/`, `test/attack/`  
**Style:** aligned with [`10-dao-governance/doc/SWC-AUDIT-EN.md`](../../10-dao-governance/doc/SWC-AUDIT-EN.md)

---

## Executive summary

| Status | Count |
|--------|----------|
| ✅ Mitigated / Not applicable | 31 |
| ⚠️ Informational (design / trust / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within the v1 scope (ERC-1967 + Transparent + UUPS + Box demo). The module **uses `delegatecall` intentionally** (SWC-112): the risk is mitigated with EIP-1967 slots, implementation validation, `_authorizeUpgrade` / `ProxyAdmin`, `_disableInitializers` and layout gaps. Informational risks: centralization of the `owner`/`ProxyAdmin`, upgrades to a malicious impl if the authorized party is compromised, and operational selector clash if the admin EOA uses the proxy as a user wallet.

**Suite principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `ProxyErrors` |
| Fixed pragma `0.8.24` | ✅ |
| EIP-1967 implementation / admin slots | ✅ + unit |
| Initializers disabled in impl | ✅ + attack |
| Upgrade access control | ✅ Transparent `Ownable2Step` + UUPS owner |
| Storage gaps / V1→V2 layout | ✅ `forge inspect` + `doc/storage-layout-EN.md` |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Unauthorized attack suite | ✅ `test/attack/` |

---

## Full SWC-100 — SWC-136 matrix

| ID | Title | Applies | Status | Evidence in Upgradeable Proxies |
|----|--------|--------|--------|----------------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; `value` fuzzing with `bound` |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | `delegatecall` checks `success`; bubbles returndata or `DelegateCallFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Partial | ✅ | Proxy is `payable` only to forward `msg.value` via `delegatecall`; no open withdraw |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Partial | ✅ | Atomic upgrades (tx reverts on failure); no external business callbacks in core; auth attack tests |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `public` / `private` / `constant` / `immutable` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | Yes | ✅ | `delegatecall` only to the impl in the EIP-1967 slot; upgrade requires auth + code + (UUPS) `proxiableUUID` |
| SWC-113 | DoS with Failed Call | Yes | ✅ | `delegatecall` failure → revert (`DelegateCallFailed` / bubble); upgrade state is not left half-done if the tx reverts |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Front-running of `upgradeToAndCall` if the owner signs/sends through the mempool; see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via `msg.sender` (owner / ProxyAdmin) |
| SWC-116 | Block values as a proxy for time | No | N/A | No on-chain time delays in v1 |
| SWC-117 | Signature Malleability | No | N/A | No signatures / `ecrecover` |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No state shadowing in core |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | No signatures |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | No signature verification |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit/e2e/fuzz/attack |
| SWC-124 | Write to Arbitrary Storage Location | Partial | ✅ | Assembly writes only known EIP-1967 slots / calldata copy; business logic in a typed layout + `__gap` |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `Initializable` + `UUPSUpgradeable` + `IBox` in Box; Transparent extends ERC1967 |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | `upgradeToAndCall` with arbitrary `data` may OOG; bounded by the authorized caller |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ⚠️ | Heavy init/migration in `data` may OOG (ops) |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII in `src/` |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead code in core |
| SWC-132 | Unexpected Ether balance | Partial | ✅ | ETH in the proxy is the proxy's balance; logic must handle `msg.value` via the impl |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | EIP-1967 slots with `keccak256` of fixed strings |
| SWC-134 | Message call with hardcoded gas | No | N/A | No `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | No relevant no-ops |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Proxy storage is public by design |

---

## Informational risks

### SWC-112 — `delegatecall` (module design)

The whole proxy pattern **depends** on `delegatecall`. v1 mitigations:

1. Delegation only to the address in the EIP-1967 slot.
2. Setting the impl requires `code.length > 0` (`InvalidImplementation`).
3. UUPS: `proxiableUUID` must return the EIP-1967 slot.
4. Upgrades only via `_authorizeUpgrade` (owner) or `ProxyAdmin.onlyOwner`.
5. Implementations call `_disableInitializers()` in the constructor.

A compromised owner can point to a malicious impl: this is a **trust/key** risk, not an anonymous bypass.

### SWC-114 — Upgrade ordering / front-running

`upgradeToAndCall` in the mempool can be front-run (same auth). Operational mitigation: private relay / multisig / timelock (outside v1; Phase 6+).

### Centralization / post-deploy trust

| Topic | Risk | v1 handling |
|------|--------|----------------|
| `Box*.owner` | Unilateral upgrade | Document; Ideal: Timelock/DAO (future) |
| `ProxyAdmin.owner` | Same for Transparent | `Ownable2Step` (rotate ownership; the proxy admin is immutable) |
| Admin = EOA that also uses the proxy | Transparent: admin cannot call user logic | Use a dedicated `ProxyAdmin` (clash tests) |
| Forgotten init | Proxy usable without state | Init in the proxy constructor (`data`) |

### SWC-126 / SWC-128 — Heavy upgrade `data`

Huge migrations in `upgradeToAndCall` may fail due to gas. Mitigation: bounded migrations / multi-step `reinitializer`.

### Storage layout

Breaking offsets when upgrading corrupts state. Mitigated with `__gap`, `forge inspect` (`doc/storage-layout-EN.md`) and persistence fuzzing.

---

## Monorepo principles checklist (+ module 11)

| Principle | Compliant? | Notes |
|-----------|----------|--------|
| Custom errors | ✅ | `InvalidImplementation`, `AlreadyInitialized`, `UnauthorizedUpgrade`, `DelegateCallFailed` |
| EIP-1967 slots | ✅ | impl + admin |
| `_disableInitializers` | ✅ | Box + UUPSCounter |
| `__gap` | ✅ | BoxV1 50 / BoxV2 49 |
| Transparent clash guard | ✅ | Admin path vs user |
| UUPS `onlyProxy` + UUID | ✅ | |
| NatSpec on public/external | ✅ | Core + Box |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/StorageUpgrade.fuzz.t.sol` |
| Attack suite | ✅ | `test/attack/UnauthorizedUpgrade.t.sol` |
| No floating pragma | ✅ | `0.8.24` |
| No ETH `transfer`/`send` | ✅ | |

---

## Verification findings (code)

### Confirmed mitigations

1. **ERC1967Proxy:** fallback/receive assembly `delegatecall`; impl slot; custom errors.
2. **TransparentProxy:** if `msg.sender == admin` (immutable) only `upgradeToAndCall`; everything else `UnauthorizedUpgrade`. Control rotation via `ProxyAdmin` Ownable2Step.
3. **UUPS:** `onlyProxy`; auth in `_authorizeUpgrade`; rejection of non-proxiable impl.
4. **Initializable:** double init / init on impl → `AlreadyInitialized`.
5. **Box V1→V2:** slots 0/1 stable; `label` in slot 2; gap 50→49.

### Phase 5–6 hardening

| # | Change | Reason |
|---|--------|--------|
| 1 | `test/UpgradeE2E.t.sol` | Full UUPS + Transparent cycle |
| 2 | `test/fuzz/StorageUpgrade.fuzz.t.sol` | Zero corruption pre/post upgrade |
| 3 | `test/attack/UnauthorizedUpgrade.t.sol` | SWC-123 / auth bypass |
| 4 | `doc/SWC-AUDIT-EN.md` | SWC-100–136 matrix (module 10 style) |
| 5 | `immutable` admin + gas opts | Hot path without admin SLOAD / without extcodesize |
| 6 | `script/Deploy.s.sol` + `doc/GAS-EN.md` | Reproducible deploy + benchmarks |

### Non-blocking observations (v2 / Phase 6)

| # | Observation | Severity | Suggested action |
|---|-------------|-----------|-----------------|
| 1 | No Timelock on upgrades | Info | Governance + delay |
| 2 | `implementation()` in the proxy ABI | Info | Possible clash if the logic exposes the same selector |
| 3 | Deploy / owner renounce scripts | Info | Phase 6 |
| 4 | Formal Foundry invariants | Improvement | store/upgrade handler |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `test/fuzz/StorageUpgrade.fuzz.t.sol` |
| SWC-103 | `forge build` fixed pragma |
| SWC-104 | `ERC1967Proxy` `DelegateCallFailed` / bubble |
| SWC-112 | E2E + UUPS `proxiableUUID` + NonUUPS reject |
| SWC-113 | `fail` / `failEmpty` in `ERC1967Proxy.t.sol` |
| SWC-114 | Documentation only |
| SWC-123 | unit + e2e + fuzz + attack |
| SWC-124 | `storage-layout-EN.md` + slot asserts e2e/fuzz |
| Auth | `test/attack/UnauthorizedUpgrade.t.sol` |
| Layout | `BoxUpgrade.t.sol` + `UpgradeE2E` + fuzz |

---

## Execution results

```text
forge test --summary
BoxUpgradeTest                   7 PASS
ERC1967ProxyTest                11 PASS
TransparentProxyTest            11 PASS
UUPSTest                        11 PASS
UpgradeE2ETest                   3 PASS
UnauthorizedUpgradeAttackTest    7 PASS
StorageUpgradeFuzzTest           4 PASS (1000 runs each)
ProxyGasTest                     6 PASS
Total: 60 PASS / 0 FAIL / 0 SKIP
```

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [EIP-1967](https://eips.ethereum.org/EIPS/eip-1967)
- [ERC-1822 (UUPS)](https://eips.ethereum.org/EIPS/eip-1822)
- Module 10: [`10-dao-governance/doc/SWC-AUDIT-EN.md`](../../10-dao-governance/doc/SWC-AUDIT-EN.md)
- Layout: [`storage-layout-EN.md`](./storage-layout-EN.md)
- Plan: [`planificacion-EN.md`](./planificacion-EN.md)
