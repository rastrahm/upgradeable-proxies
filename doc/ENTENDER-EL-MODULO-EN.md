# Understanding the module — Decisions, logic and gas

> 🌐 **English** · [Español](./ENTENDER-EL-MODULO-ES.md) · [Index](../README.md)

Document for reading the **Upgradeable Proxies (module 11)** project without having to reconstruct the design from the code.

Related: [`planificacion-EN.md`](./planificacion-EN.md) · [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · [`flujograma-EN.md`](./flujograma-EN.md)

---

## 1. The idea in one sentence

The **proxy** is the fixed address users interact with. The **implementation** is the code that gets executed. State lives in the proxy. Changing versions = changing a pointer (EIP-1967 slot), not migrating balances to another contract.

```
User ──► Proxy (storage + stable address)
                │
                │  delegatecall
                ▼
         Implementation V1 / V2 (logic only)
```

---

## 2. Technical decisions (why it was done this way)

### 2.1 Two patterns, not one

| Pattern | Where upgrade control lives | Why it exists |
|--------|----------------------------------|----------------|
| **Transparent** | Separate contract (`ProxyAdmin`) | Avoids *function clash*: the admin never executes business logic by mistake |
| **UUPS** | Inside the implementation (`_authorizeUpgrade`) | Fewer contracts in the path; the proxy is "dumber" and cheaper |

**Decision:** implement **both** to learn the real tradeoff (gas, attack surface, DX), rather than picking one blindly.

### 2.2 EIP-1967 for the logic pointer

Do not store `address implementation` in slot 0 of the proxy.

**Why:** slot 0 will be used by the business logic via `delegatecall`. If the proxy and the impl fight over the same slot → storage corruption.

**Decision:** canonical slots:

- implementation: `keccak256("eip1967.proxy.implementation") - 1`
- admin (Transparent): `keccak256("eip1967.proxy.admin") - 1`

### 2.3 `delegatecall`, not `call`

With `call`, state would be written to the implementation. With `delegatecall`, it is written to the **proxy** and `msg.sender` / `msg.value` are preserved.

**Decision:** all user routing goes through `delegatecall` in assembly (fallback / receive).

### 2.4 Initializable + `_disableInitializers()`

The impl's constructors do **not** initialize the proxy's storage (the constructor runs at the impl's address).

**Decision:**

1. The Box/UUPS constructor calls `_disableInitializers()` → nobody can "take over" the standalone impl.
2. `initialize(...)` is called **via the proxy** (calldata in the proxy constructor, or later, in a controlled way).

### 2.5 Storage gaps (`__gap`)

BoxV1 reserves `uint256[50] __gap`. BoxV2 adds `label` and reduces the gap to 49.

**Decision:** new variables **only at the end** of the layout. Documented in [`storage-layout-EN.md`](./storage-layout-EN.md) with `forge inspect`.

### 2.6 Immutable admin in Transparent (Phase 6)

OZ v5 also fixes the admin as immutable.

**Decision:**

- Routing uses `_adminAddress` (immutable) → no SLOAD on every user call.
- The EIP-1967 slot is written **once** in the constructor (`eth_getStorageAt` compatibility).
- There is **no** `changeAdmin` in the proxy: rotating control = `transferOwnership` / `acceptOwnership` on the `ProxyAdmin`.

### 2.7 Module custom errors

`InvalidImplementation`, `AlreadyInitialized`, `UnauthorizedUpgrade`, `DelegateCallFailed`.

**Decision:** cheap, typed reverts; aligned with the suite (no `require` with strings).

### 2.8 What was left out (on purpose)

| Excluded in v1 | Reason |
|-------------|--------|
| Beacon / Diamond | A different complexity module |
| Timelock / DAO for upgrades | Owner trust documented as an informational risk |
| Frontend | Outside the scope of contracts |

---

## 3. Logic followed by the system

### 3.1 Happy path — UUPS (Box)

```
1. Deploy BoxV1          → constructor disables initializers
2. Deploy ERC1967Proxy(impl, initData)
                         → writes impl slot
                         → delegatecall initialize(owner, value)
3. User: store(x)        → fallback → delegatecall → PROXY storage
4. Owner: upgradeToAndCall(BoxV2, initializeV2)
                         → delegatecall to V1.upgradeToAndCall
                         → _authorizeUpgrade (owner only)
                         → validates V2's proxiableUUID
                         → writes slot → V2
                         → delegatecall initializeV2
5. User: retrieve()      → same value; version() == "2"
```

### 3.2 Happy path — Transparent

```
1. Deploy ProxyAdmin(owner)
2. Deploy TransparentProxy(impl, admin=ProxyAdmin, data?)
3. User → proxy → delegatecall to logic
4. Owner → ProxyAdmin.upgradeAndCall(proxy, newImpl, data)
        → proxy sees msg.sender == admin → admin path (NO business delegatecall)
        → changes impl slot
```

### 3.3 Routing rules (Transparent)

| Who calls | What happens |
|-------------|----------|
| `msg.sender != admin` | Always `delegatecall` to the impl (even if the selector is `upgradeToAndCall`) |
| `msg.sender == admin` and selector `upgradeToAndCall` | Actual upgrade on the proxy |
| `msg.sender == admin` and any other selector | `UnauthorizedUpgrade` (the admin does not use the proxy as a user wallet) |

### 3.4 Upgrade rules (UUPS)

| Check | If it fails |
|-------|----------|
| Call via proxy (`onlyProxy`) | `UnauthorizedUpgrade` |
| `_authorizeUpgrade` (e.g. owner) | `UnauthorizedUpgrade` |
| New impl without code / wrong UUID / not UUPS | `InvalidImplementation` |
| Second `initialize` | `AlreadyInitialized` |

### 3.5 Mental map of responsibilities

```
ERC1967Proxy     → "how I route" (slot + delegatecall)
TransparentProxy → "who is admin vs user"
ProxyAdmin       → "who can request the upgrade" (Ownable2Step)
UUPSUpgradeable  → "how the upgrade is authorized and validated from the logic"
Initializable    → "how state is initialized exactly once"
BoxV1 / BoxV2    → "what the business does" + gaps
```

---

## 4. Gas: what is already optimized

Phase 6 summary (numeric details in [`GAS-EN.md`](./GAS-EN.md)):

1. **Immutable** admin in Transparent.
2. **No** `extcodesize` in the fallback hot path.
3. EIP-1967 slots as precomputed **constants**.
4. `delegatecall` in **assembly**.
5. Upgrades with **`bytes calldata`** (less copying to memory).
6. No on-proxy `changeAdmin` (less bytecode).
7. `optimizer_runs = 10_000` + `via_ir`.

Deliberate priority: **user runtime** (every `store` / `retrieve`) > deploy cost.

---

## 5. Can gas be improved further?

Yes, but almost everything is **marginal** or comes with a **security / clarity cost**. None of this is "free".

### 5.1 Possible improvements (ordered by realistic impact)

| Idea | Expected savings | Risk / cost | Worth it in v1? |
|------|-----------------|----------------|----------------------|
| Remove the `implementation()` / `admin()` getters from the proxy ABI | Deploy + avoids selector clashes | More awkward ops (read storage only) | Optional |
| Minimal proxy (EIP-1167) in front of UUPS just for clones | Much cheaper deploy per instance | Not the same "single upgradeable proxy" product | Different design |
| Pack `owner` + flags into a single slot in Box | ~1 fewer SLOAD in auth/views | More fragile layout + gaps | Only if the business grows |
| `version()` as `bytes32` / `uint8` instead of `string` | Less gas per call + bytecode | Less readable API | Micro |
| Remove the `Upgraded` / `AdminChanged` events | Gas on upgrade / deploy | Worse off-chain indexing | Not recommended |
| Custom, more minimal `ProxyAdmin` (without Ownable2Step) | Cheaper admin deploy | You lose 2-step (worse UX/security) | No |
| Even more aggressive assembly in Transparent `_fallback` | Tens of gas | Readability / auditability | Only with a benchmark |
| Lower `optimizer_runs` | Cheaper deploy | More expensive runtime | Contrary to the module's goal |

### 5.2 What you should **not** "optimize"

| Temptation | Why not |
|-----------|------------|
| Put `implementation` in slot 0 | Collides with the logic's storage |
| Skip `proxiableUUID` in UUPS | You can brick the proxy by upgrading to something non-UUPS |
| Re-enable `extcodesize` on every call "just in case" | Burns gas in the hot path; setting the impl already validates |
| Reorder storage in V2 "to compact it" | Corrupts user state |

### 5.3 Where there is real room (outside the proxy)

The proxy is already thin. The heavy gas usually lives in **the business logic**:

- fewer SSTOREs,
- fewer hot reads,
- typed calldata,
- avoid dynamic strings in the hot path.

Example: in Box, `store` / `retrieve` are close to the minimum possible; the cost you see in tests includes Foundry overhead + cold storage on the first write.

### 5.4 How to measure before touching anything

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract ProxyGasTest --gas-report
forge snapshot --match-contract ProxyGasTest
```

Rule: **do not merge an "optimization" without a measured Δ** in the same test.

---

## 6. How to read the repo (suggested order)

1. `src/proxy/ERC1967Proxy.sol` — the heart of the routing  
2. `src/proxy/TransparentProxy.sol` + `ProxyAdmin.sol` — admin vs user  
3. `src/uups/UUPSUpgradeable.sol` + `src/utils/Initializable.sol` — upgrade from the logic  
4. `src/implementations/BoxV1.sol` → `BoxV2.sol` — layout + gap  
5. `test/UpgradeE2E.t.sol` + `test/attack/` + `test/fuzz/` — expected behavior  
6. `doc/GAS-EN.md` + `doc/SWC-AUDIT-EN.md` — tradeoffs and security  

---

## 7. Mental checklist (if you have to explain it in an interview tomorrow)

1. State in the **proxy**, code in the **impl**.  
2. Pointer in the **EIP-1967** slot, not in slot 0.  
3. Transparent separates **who upgrades**; UUPS puts the auth in the **logic**.  
4. Init **via the proxy**; the impl is born with initializers **locked**.  
5. Gaps so storage does not break in V2.  
6. Gas: keep the **fallback** cheap; do not give away security for 200 gas.  

---

*Last updated: aligned with the post-Phase 6 code (immutable admin, suite 60 PASS).*
