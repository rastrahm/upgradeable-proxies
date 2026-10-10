# Planning — Module 11: Upgradeable Proxies (UUPS & Transparent)

> 🌐 **English** · [Español](./planificacion-ES.md) · [Index](../README.md)

**Status:** Phases **0–6** ✅ completed. Module closed at the v1 planning level.  
**Progress rule:** each phase requires **explicit authorization** from the owner before starting.

---

## 1. Objective

Build a production-grade set of upgradeable proxy contracts with:

- **Transparent Proxy** pattern (ERC-1967) + separate admin.
- **UUPS** pattern with upgrade authorization in the implementation (`_authorizeUpgrade`).
- Correct EIP-1967 slots; `delegatecall` in the fallback (assembly).
- Safe initialization (`Initializable` + `_disableInitializers()`).
- Storage gaps (`uint256[50] __gap`) to avoid collisions during upgrades.
- Stack: **Foundry + Solidity `0.8.24`** (fixed pragma).

---

## 2. Scope

| Included | Excluded (v1) |
|----------|----------------|
| ERC-1967 proxy, Transparent, UUPS, V1/V2 impl, tests, storage-layout | Beacon Proxy / Diamond (EIP-2535) |
| 2-step admin / owner for upgrades | DAO governance of the upgrade |
| Module custom errors | Complex multi-clone proxy factory |
| Fuzz + unauthorized upgrade tests | Frontend (optional later phase) |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite`)

- Solidity **exactly** `0.8.24`.
- OpenZeppelin Contracts v5.x where it provides audited inheritance (or a custom implementation aligned with EIP-1967).
- Foundry: unit + fuzz (`runs >= 1000`) + `forge inspect <Contract> storage-layout`.
- Custom errors (no `require` with strings).
- CEI / access control on administrative functions.
- NatSpec on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.

### Module 11

- Implementation slot: `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)`.
- Admin slot (Transparent): `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`.
- Routing only via `delegatecall` in fallback/assembly; preserve `msg.sender` and `msg.value`.
- Implementation constructors disabled with `_disableInitializers()`.
- Upgrades only by admin / `_authorizeUpgrade`.

---

## 4. Planned architecture

```
11-upgradeable-proxies/
├── doc/                          ← planning and diagrams (this folder)
├── src/
│   ├── proxy/
│   │   ├── ERC1967Proxy.sol      # base: impl slot + fallback delegatecall
│   │   ├── TransparentProxy.sol  # admin vs user (function clash guard)
│   │   └── ProxyAdmin.sol        # owner of the transparent proxy; upgradeToAndCall
│   ├── uups/
│   │   └── UUPSUpgradeable.sol   # upgradeToAndCall + _authorizeUpgrade
│   ├── utils/
│   │   └── Initializable.sol     # initializer / reinitializer / disable
│   ├── implementations/
│   │   ├── BoxV1.sol             # example state + gap
│   │   └── BoxV2.sol             # new logic; compatible layout
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

### Contracts and responsibilities

| Contract | Responsibility |
|----------|-----------------|
| `ERC1967Proxy` | Stores impl in the EIP-1967 slot; `delegatecall` in fallback |
| `TransparentProxy` | If `msg.sender == admin` → admin functions; otherwise → delegatecall to impl |
| `ProxyAdmin` | Sole privileged caller of the Transparent proxy for upgrades |
| `UUPSUpgradeable` | Upgrade logic in the impl; `_authorizeUpgrade` |
| `Initializable` | `initializer` / protection against re-init |
| `BoxV1` / `BoxV2` | State demo + upgrade with persistence |

---

## 5. Custom errors (mandatory for the module)

```solidity
error InvalidImplementation();
error AlreadyInitialized();
error UnauthorizedUpgrade();
error DelegateCallFailed();
```

Extend only if needed (e.g. `ZeroAddress()`, `InvalidAdmin()`), always as custom errors.

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|-------|---------|
| **Gate** | No code for a phase is written until you explicitly say: *"I authorize Phase N"* (or equivalent). |
| **Delivery** | When closing a phase: acceptance checklist + summary of files touched. |
| **Blocking** | If new scope appears, it is documented and new authorization is awaited. |
| **TDD** | Within each contract phase: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|------|--------|--------|--------------|
| 0 | Foundry setup + structure | ✅ Completed | ✅ Authorized |
| 1 | ERC-1967 core + `delegatecall` | ✅ Completed | ✅ Authorized |
| 2 | Transparent Proxy + `ProxyAdmin` | ✅ Completed | ✅ Authorized |
| 3 | UUPS + `Initializable` | ✅ Completed | ✅ Authorized |
| 4 | BoxV1 / BoxV2 implementations + gaps | ✅ Completed | ✅ Authorized |
| 5 | Test suite (persistence, unauthorized, fuzz, storage-layout) | ✅ Completed | ✅ Authorized |
| 6 | Deploy scripts + NatSpec / SWC hardening + gas | ✅ Completed | ✅ Authorized |

---

## 7. Phase details

### Phase 0 — Foundry setup ✅

**Objective:** empty compilable repo with tooling ready.

1. `forge init` (or minimal structure compatible with the suite).
2. `foundry.toml`: solc `0.8.24`, fuzz runs ≥ 1000.
3. OZ v5 dependencies if primitives are reused.
4. Folders `src/`, `test/`, `script/`, `doc/` (already created).

**Exit criterion:** `forge build` OK with no business contracts yet (or with a stub).

**Done (2026-09-08):** `foundry.toml` + `remappings.txt`; `forge-std` + OZ `v5.2.0` in `lib/` (gitignored); `Placeholder` stub + smoke test; folders `src/{proxy,uups,utils,implementations,interfaces}` and `test/fuzz` prepared. `forge build` and `forge test` green.

---

### Phase 1 — ERC-1967 core + delegatecall ✅

**Objective:** minimal proxy that routes calldata to the implementation.

1. Tests: deploy proxy → call via proxy mutates the proxy's storage (not the impl's).
2. Implement read/write of the EIP-1967 implementation slot.
3. Fallback/receive in assembly with `delegatecall`; failure → `DelegateCallFailed`.
4. Validate `implementation != address(0)` → `InvalidImplementation`.

**Exit criterion:** a call through the proxy persists state at the proxy's address.

**Done:** `ERC1967Proxy`, `ProxyErrors`, `CounterLogic` mock, `test/ERC1967Proxy.t.sol` suite (EIP-1967 slot, persistence, `msg.value`, init data, errors). `Placeholder` stub removed.

---

### Phase 2 — Transparent Proxy + ProxyAdmin ✅

**Objective:** separate the admin path from the user path (avoid function clashes).

1. Tests: user calls an impl function → delegatecall; admin calls upgrade → no delegatecall to the user selector.
2. EIP-1967 admin slot.
3. `ProxyAdmin` with `upgradeToAndCall` and ownership (`Ownable2Step` preferred).
4. Revert `UnauthorizedUpgrade` if a non-admin attempts an upgrade.

**Exit criterion:** admin/user clash covered by tests.

**Done:** `TransparentProxy` (admin dispatch in fallback), `ProxyAdmin` (`Ownable2Step`), `CounterLogicV2` / `ClashingLogic` mocks, `test/TransparentProxy.t.sol` suite.

---

### Phase 3 — UUPS + Initializable ✅

**Objective:** authorized upgrade from the implementation.

1. Tests: `upgradeToAndCall` only after `_authorizeUpgrade` succeeds.
2. `UUPSUpgradeable` with proxiable UUID / ERC-1967 check.
3. `Initializable`: a single `initialize`; the constructor calls `_disableInitializers()`.
4. Reverts: `AlreadyInitialized`, `UnauthorizedUpgrade`, `InvalidImplementation`.

**Exit criterion:** UUPS happy-path upgrade + error paths green.

**Done:** `Initializable`, `UUPSUpgradeable`, `UUPSCounter` / `UUPSCounterV2` / `NonUUPSLogic` mocks, `test/UUPS.t.sol` suite.

---

### Phase 4 — BoxV1 / BoxV2 + storage gaps ✅

**Objective:** upgradeable business demo with a safe layout.

1. `BoxV1`: state (`value`, `owner`, …) + `uint256[50] __gap`.
2. `BoxV2`: new functions / variables **only at the end** of the layout (after the gap or by shrinking the gap).
3. Tests: set state in V1 → upgrade to V2 → same values.
4. `forge inspect BoxV1 storage-layout` and `BoxV2 storage-layout` documented.

**Exit criterion:** state persistence verified; compatible layouts.

**Done:** `IBox`, `BoxV1`, `BoxV2`, `test/BoxUpgrade.t.sol`, `doc/storage-layout-EN.md` (slots 0/1 stable; `label` in slot 2; gap 50→49).

---

### Phase 5 — Full test suite ✅

**Objective:** testing requirements from the module's `.cursorrules`.

| Type | What it validates |
|------|------------|
| Unit e2e | Deploy → mutate → upgrade → assert state |
| Unauthorized | A non-admin cannot `upgradeToAndCall` |
| Storage layout | V1↔V2 compatibility (`forge inspect`) |
| Fuzz | State variables pre/post upgrade without corruption |

**Exit criterion:** `forge test` green; fuzz with no unexpected failures.

**Done:** `test/UpgradeE2E.t.sol`, `test/attack/UnauthorizedUpgrade.t.sol`, `test/fuzz/StorageUpgrade.fuzz.t.sol` (1000 runs), `doc/SWC-AUDIT-EN.md` (module 10 style). **54 PASS**.

---

### Phase 6 — Deploy + hardening + gas ✅

1. `script/Deploy.s.sol` (Transparent and UUPS).
2. Complete NatSpec; SWC checklist relevant to proxies.
3. `doc/SWC-AUDIT-EN.md` / `doc/GAS-EN.md` in the style of previous modules.

**Exit criterion:** reproducible local deploy + security docs + documented gas.

**Done:** UUPS+Transparent deploy; gas opts (admin `immutable`, no extcodesize on the hot path, calldata upgrades, precomputed slots); `test/gas/Proxy.gas.t.sol`; `doc/GAS-EN.md`. **60 PASS**.

---

## 8. Test matrix (global objective)

| Case | What it validates |
|------|------------|
| Post-upgrade persistence | Proxy storage intact after changing impl |
| Unauthorized upgrade | `UnauthorizedUpgrade` |
| Double init | `AlreadyInitialized` |
| Zero / invalid impl | `InvalidImplementation` |
| Delegatecall fail | `DelegateCallFailed` |
| Transparent clash | Admin does not accidentally execute user logic |
| State fuzz | Zero corruption of used slots |

---

## 9. Security (living checklist)

- [x] Correct EIP-1967 slots (not the impl's ordinary storage).
- [x] `_disableInitializers()` in implementation constructors.
- [x] `__gap` gaps in upgradeable bases.
- [x] Upgrades with strict access control.
- [x] `delegatecall` only in the proxy; no business logic in the proxy (except the Transparent admin path).
- [x] Module custom errors.
- [x] No floating pragma; NatSpec on public APIs.
- [x] Attack + fuzz suite + `doc/SWC-AUDIT-EN.md`.

---

## 10. Documentation deliverables (`doc/`)

| File | Content |
|---------|-----------|
| `planificacion-EN.md` | This document (phases + gates) |
| `diagrama-de-clases-EN.md` | Structure and relationships between contracts |
| `diagrama-de-flujo-EN.md` | Decision flows (init, upgrade, routing) |
| `flujograma-EN.md` | End-to-end actor–system flows |
| `storage-layout-EN.md` | BoxV1/BoxV2 layout (`forge inspect`) |
| `SWC-AUDIT-EN.md` | SWC-100–136 matrix + informational risks |
| `GAS-EN.md` | Phase 6 optimizations and benchmarks |

---

## 11. Module acceptance criteria

1. Compiles with `pragma solidity 0.8.24`.
2. Transparent and UUPS operational with e2e tests.
3. State persists after the V1 → V2 upgrade.
4. Unauthorized upgrades revert.
5. `forge inspect` confirms compatible layouts.
6. Pre/post-upgrade state fuzzing green.
7. NatSpec + custom errors on public APIs.

---

## 12. Next step

**Module v1 complete (Phases 0–6).** Possible extensions: Timelock on upgrades, Foundry invariants, frontend.

**Note:** use `~/.foundry/bin/forge` (or prepend `$HOME/.foundry/bin` to `PATH`); the `forge` from nvm/npm is not Foundry.
