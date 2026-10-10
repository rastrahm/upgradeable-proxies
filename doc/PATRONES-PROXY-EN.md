# Proxy patterns — Beacon, Clones, Diamond + comparison table

> 🌐 **English** · [Español](./PATRONES-PROXY-ES.md) · [Index](../README.md)

> *Beacon* = **lighthouse**. *Minimal proxy* = cheap **cup**. *Diamond* = **building with many offices** (facets).

Related: [`ENTENDER-EL-MODULO-EN.md`](./ENTENDER-EL-MODULO-EN.md) · module 11 (UUPS + Transparent).

---

## 1. Beacon Proxy — detailed explanation

### 1.1 Problem it solves

With **classic** UUPS/Transparent, each proxy stores **its own** EIP-1967 implementation slot.

If you deploy **1,000 vaults** (one per user) and want to upgrade the logic for all of them:

- without a beacon → 1,000 `upgradeTo(...)` transactions (or a very expensive script),
- with a beacon → **1** change in the beacon; all proxies read the new target.

### 1.2 Components

```
                 ┌──────────────────────┐
   Owner/Admin ─►│  UpgradeableBeacon   │  ← stores address implementation
                 │  (the "lighthouse")  │     + upgradeTo(newImpl) function
                 └──────────┬───────────┘
                            │ implementation()
           ┌────────────────┼────────────────┐
           ▼                ▼                ▼
     BeaconProxy A    BeaconProxy B    BeaconProxy C
     (storage user A) (storage user B) (storage user C)
           │                │                │
           └──── delegatecall to the SAME impl ────┘
```

| Contract | Role |
|----------|-----|
| **UpgradeableBeacon** | Small contract: `implementation()` + `upgradeTo` (owner only). It is the source of truth. |
| **BeaconProxy** | Per-instance proxy. On every call: asks the beacon "which impl is it?" → `delegatecall` to that address. |
| **Implementation** | Shared logic. Each user's **state** lives in **their** BeaconProxy, not in the beacon. |

### 1.3 Call flow

```
1. User calls BeaconProxyA.deposit()
2. Proxy fallback:
   a) beacon.implementation()  →  0xLogicV2
   b) delegatecall(0xLogicV2, calldata)
3. deposit() writes balances to BeaconProxyA's storage
```

The beacon does **not** store the deposits. It only answers: "today the logic is this one".

### 1.4 Upgrade flow

```
1. Owner → UpgradeableBeacon.upgradeTo(LogicV3)
2. BeaconProxyA / B / C do not change their code
3. On the next call, each proxy asks the beacon and already uses LogicV3
```

One upgrade → global effect on every instance pointing to that beacon.

### 1.5 Slot / standard

OpenZeppelin uses the EIP-1967 **beacon** slot:

`bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)`

The proxy stores the address of the **beacon** (not necessarily the impl's). The impl is resolved at runtime.

### 1.6 Common combination: clones + beacon

Often:

1. You deploy **one** logic contract + **one** beacon.
2. For each user: a cheap `clone` (EIP-1167) or `BeaconProxy`.
3. Upgrade = touch the beacon.

This gives you: **cheap per-instance deployment** + **mass upgrade**.

### 1.7 Beacon-specific risks

| Risk | Detail |
|--------|---------|
| **Blast radius** | A bad upgrade affects **all** instances at once |
| **Trust in the beacon owner** | Whoever controls the beacon controls the logic of the entire set |
| **Extra call** | Every tx performs (at least) one read/`STATICCALL` to the beacon → slightly more gas than UUPS with a local slot |
| **Shared layout** | All instances must follow the same storage layout of the logic |

### 1.8 Beacon vs UUPS vs Transparent (intuition)

| | Who holds the pointer to the logic | Upgrading N instances |
|--|------------------------------------|-------------------------|
| UUPS / Transparent | Each proxy | N upgrades |
| Beacon | The beacon (shared) | 1 upgrade |

Beacon does not fully replace UUPS/Transparent: sometimes the **impl** behind the beacon is UUPS… but the usual setup is: the beacon owner upgrades the logic, and the proxies just delegate.

---

## 1B. Minimal Proxy (EIP-1167 / clones) — detailed explanation

### What is it, in one sentence?

An **almost empty contract** (~45 bytes of bytecode) whose only job is:  
**"whatever you send me, I forward it via `delegatecall` to this fixed implementation".**

It is not a "smart" proxy like Transparent. It is a **cheap photocopy** of a master contract.

Analogy:

- **Implementation** = the mold / recipe.  
- **EIP-1167 clone** = a disposable cup with your coffee (your storage).  
- All cups use the **same** recipe, but each one has **its own** contents.

### Problem it solves

Deploying the same "fat" contract (vault, wallet, account) 1,000 times costs a fortune in gas (large bytecode × N).

With clones:

1. You deploy the full logic (`Implementation`) **once**.  
2. For each user/instance you deploy only a minimal **stub** that points to that logic.  
3. Each clone has **its own address and its own storage**.

### How it works technically

The minimal proxy bytecode is a fixed template. The implementation address is **burned in** (hardcoded) in the middle:

```
runtime ≈ 
  calldatacopy
  delegatecall(gas, <IMPLEMENTATION_ADDRESS>, …)
  return / revert
```

- There is no `sload` of an EIP-1967 slot in the classic clone.  
- The impl is **in the proxy's bytecode**.  
- That is why deployment is so cheap: there is almost no code.

OpenZeppelin: `Clones.clone(implementation)` / `Clones.cloneDeterministic(...)`.

### Call flow

```
1. Deploy Implementation (full logic)             → 0xLogic
2. Factory creates clone(0xLogic)                → 0xCloneUserA  (small bytecode)
3. User calls 0xCloneUserA.deposit()
4. Clone fallback:
      delegatecall(0xLogic, calldata)
5. deposit() writes to 0xCloneUserA's storage
```

Same as any proxy: **state in the clone**, **code in the impl**.

### Initialization (very important)

The Implementation's **constructor** runs when `0xLogic` is deployed, **not** when each clone is created.

That is why clonable impls:

- use `initialize(...)` (like upgradeables),
- often call `_disableInitializers()` in the impl's constructor,
- the factory does: `clone` + `initialize(owner, …)` in the same tx.

If you do not initialize the clone, it stays empty / can be taken over by someone else.

### `clone` vs `cloneDeterministic` (CREATE2)

| | |
|--|--|
| **clone** | New "random" address (based on nonce). |
| **cloneDeterministic** | **Predictable** address with a `salt` (CREATE2). Useful for "counterfactual" wallets, same address cross-chain (carefully), etc. |

### Is the clone upgradeable?

**Pure EIP-1167: no.**  
The logic address is **fixed in the clone's bytecode**. There is no `upgradeTo` in the stub.

To upgrade **all** clones:

| Strategy | How |
|------------|------|
| **Clone → fixed impl** | No upgrade (or migration to new clones). |
| **Clone + Beacon** | The clone's "implementation" points to a pattern where the logic is resolved via a beacon… *or* you use BeaconProxy instead of pure 1167. In practice: **BeaconProxy / clones that delegate to an upgradeable proxy**, or a factory that points clones to a beacon-aware address. The cleanest option: **BeaconProxy** (or UUPS behind a factory) if you need mass upgrades. |
| **UUPS impl behind each clone** | Each clone is a "cheap" ERC1967/UUPS, not pure 1167; a different design. |

Mental summary:

```
1167 alone       = cheap + shared logic + NO easy upgrade
1167 + beacon    = cheap + mass upgrade (via Beacon or equivalent)
Single UUPS/Transparent = one proxy, individual upgrade
```

*(Fine detail: a classic 1167 minimal proxy embeds a fixed address. If that address is an **intermediary contract** that in turn resolves the logic, you can compose patterns; the usual approach in OZ docs is: Clones pointing to an impl, or BeaconProxy for joint upgrades.)*

### Typical components in a factory

```
┌─────────────────────┐
│ Implementation      │  ← logic (initialize, deposit, …)
└──────────┬──────────┘
           │ pointed to by
┌──────────▼──────────┐
│ Factory             │  ← clone() + initialize()
└──────────┬──────────┘
           │ creates
    ┌──────┴──────┐
    ▼             ▼
 Clone A       Clone B     ← storage A / storage B
```

### Gas / size

| | Full contract | Minimal proxy |
|--|-------------------|---------------|
| Runtime size | Thousands of bytes | ~45 bytes |
| Instance deployment cost | High | Very low |
| Cost per call | Normal | + small `delegatecall` overhead |

The savings come from **creating many instances**, not from each call being cheaper than a monolithic contract (`delegatecall` has its own cost).

### Risks / precautions

| Risk | Detail |
|--------|---------|
| **Impl not properly initializable** | Clones can be taken over / garbage state |
| **Believing it is upgradeable** | Pure 1167 does not change impl by itself |
| **Storage layout** | All clones share the layout of the same logic |
| **`selfdestruct` in the impl** | Historically could break clones; today `SELFDESTRUCT` is heavily restricted — still: do not design destructive logic in the shared impl |
| **Malicious factory / salt** | Misused CREATE2 → address collisions or salt front-running |

### Minimal proxy vs Beacon vs UUPS (intuition)

| | Question it answers |
|--|------------------------|
| **UUPS / Transparent** | "How do I upgrade **this** single system?" |
| **Beacon** | "How do I upgrade **many** instances at once?" |
| **EIP-1167** | "How do I **create** many cheap instances of the same logic?" |

That is why they are combined: **1167 solves mass deployment; Beacon solves mass upgrades.**

### Final analogy

- Beacon = the town **lighthouse** (which manual to use today).  
- Minimal proxy = a **disposable cup** with your coffee: extremely cheap to make, each with its own contents, all following the same recipe printed on the bottom of the cup.  
- If the recipe is **tattooed** on the cup (pure 1167), you cannot change it.  
- If the cup says "look at the lighthouse" (BeaconProxy), you change the lighthouse and everyone updates the manual.

---

## 1C. Diamond (EIP-2535) — detailed explanation

### What is it, in one sentence?

A **single proxy** (the Diamond) whose address is stable, but the logic does not live in a single contract: it is spread across several contracts called **facets**.  
The Diamond has a table: **function selector → address of the facet** that implements it.

Analogy:

- **UUPS/Transparent** = a building with **a single blueprint** (one impl). To renovate, you replace the entire blueprint.  
- **Diamond** = a building with **many offices**. You renovate the accounting floor without touching marketing. The building's address (proxy) does not change.

### Problem it solves

1. **Contract size limit** (~24 KB of runtime bytecode on Ethereum). A huge protocol does not fit in a single contract.  
2. **Partial upgrades**: you do not want to redeploy / re-point *all* the logic because of a bug in one function.  
3. **Modular organization**: teams or modules (NFT, marketplace, royalties, admin) in separate contracts, same public address.

Diamond is not "for a Box with `store`/`retrieve`". It is for **large, long-lived** systems.

### System components

```
                    ┌─────────────────────────────────────┐
   User ───────────►│           Diamond (proxy)           │  fixed address
                    │  fallback: selector → facet address │
                    │  storage of the ENTIRE system       │
                    └──────────────┬──────────────────────┘
                                   │ delegatecall
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
    FacetA (ERC20)          FacetB (Staking)         FacetC (Admin)
    transfer, approve       stake, unstake           pause, setFee
```

| Component | Role |
|-------|-----|
| **Diamond** | Proxy + global storage. It does not hold all the business logic; it routes. |
| **Facet** | Contract with a subset of functions. Executed via `delegatecall` → writes to the Diamond's storage. |
| **DiamondCut** | Facet (or logic) that **adds / replaces / removes** selectors in the table. It is the system's "upgrade". |
| **DiamondLoupe** | Introspection facet: "which facets exist?", "which selectors does this facet have?". Standard for explorers/tools. |
| **Ownership / Access** | Who can perform `diamondCut` (owner, multisig, DAO…). |

### Call flow

```
1. User calls Diamond.stake(100)
2. Diamond fallback:
   a) selector = bytes4(keccak256("stake(uint256)"))
   b) facet = selectorToFacet[selector]   →  FacetStaking
   c) delegatecall(FacetStaking, calldata)
3. stake() modifies storage in the Diamond (not in FacetStaking)
```

Same as always: **state in the proxy (Diamond)**; **code in the facet**.

### Upgrade flow: `diamondCut`

There is no single `upgradeTo(newImpl)`. There is a **cut** that modifies the selector table:

```solidity
// Conceptual idea (simplified)
enum FacetCutAction { Add, Replace, Remove }

struct FacetCut {
    address facetAddress;
    FacetCutAction action;
    bytes4[] functionSelectors;
}

function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata calldataInit) external;
```

Examples:

| Action | Effect |
|--------|--------|
| **Add** | New selectors → NewFacet (new feature) |
| **Replace** | Same selectors → FacetV2 (bugfix for a module) |
| **Remove** | Selectors cease to exist (deprecate API) |

Optional: `init` + `calldata` = migration/setup `delegatecall` right after the cut (similar to `upgradeToAndCall`).

### Storage: the most delicate point

Since **all** facets share the Diamond's storage, the collision risk is high if each facet declares `uint256 x` in slot 0.

Common patterns:

| Approach | Idea |
|---------|------|
| **Diamond Storage** | Each module uses a struct in a namespaced slot (`keccak256("com.miapp.staking")`). |
| **AppStorage** | A single global struct that all facets import (fixed order; fragile if you reorder). |
| **ERC-7201** | Storage namespaces (like `Initializable` in OZ) |

Golden rule: **never** assume "my variable is in slot 0" in a standalone facet.

### Loupe (EIP-2535 introspection)

Typical functions (ideas):

- `facets()` — lists facets + selectors  
- `facetFunctionSelectors(address)`  
- `facetAddresses()`  
- `facetAddress(bytes4 selector)`  

They let wallets, explorers, and auditors **see** the shape of the diamond on-chain.

### Diamond vs UUPS vs Beacon (intuition)

| | Upgrade unit | How many active "impls" |
|--|-------------------|-------------------------|
| **UUPS / Transparent** | All the logic | 1 |
| **Beacon** | All the logic (for N proxies) | 1 shared |
| **Diamond** | Per facet / per selector | Many at once |

```
A single product, medium-sized logic?       → UUPS / Transparent
Thousands of instances, same logic?         → Beacon + clones
A modular monster at a single address?      → Diamond
```

### Advantages (why it exists)

1. **Scale beyond 24 KB** by splitting code.  
2. **Surgical upgrade** (only one module).  
3. **A single address** for users and integrations.  
4. **Teams working in parallel** on different facets (with storage discipline).  
5. **Remove** obsolete functions without redeploying "everything".

### Disadvantages (why it is scary)

| Drawback | Detail |
|--------|---------|
| **Complexity** | Cuts, loupe, storage namespaces, permissions… steep curve |
| **Expensive audits** | More surface; storage bugs are subtle |
| **Selector clash** | Two facets cannot claim the same `bytes4` |
| **Gas** | Facet lookup + `delegatecall` (acceptable, but not "free") |
| **Tooling** | Fewer "batteries included" than OZ UUPS for small teams |
| **Cut governance** | Whoever performs `diamondCut` is the god of the protocol |

### Typical risks

1. **Storage collision** between facets → state corruption.  
2. **Malicious / compromised cut** → replacement of any function.  
3. Dangerous **init calldata** in the cut (migration that overwrites storage).  
4. **Forgotten facet** with poorly protected critical (admin) selectors.  
5. **Over-engineering**: using Diamond where UUPS was enough.

### Mental anatomy of a safe `diamondCut`

```
1. Multisig / Timelock proposes the cut
2. Review: which selectors Add/Replace/Remove + new audited facet
3. Verify there is no selector clash
4. Verify storage layout / namespace of the new facet
5. Execute diamondCut (+ migration init if applicable)
6. Loupe: confirm the resulting table
7. E2E tests of the affected modules
```

### Downgrade in a Diamond?

Yes, in the sense of **Replacing** selectors with an old facet (or Remove + Add).  
More flexible than UUPS "all or nothing", but storage remains the current one: there is no magic rewind.

### Example selector map (toy)

| Selector | Facet |
|----------|--------|
| `transfer(address,uint256)` | FacetERC20 |
| `stake(uint256)` | FacetStaking |
| `diamondCut(...)` | FacetCut |
| `facets()` | FacetLoupe |
| `pause()` | FacetAdmin |

The user always calls **one** address: the Diamond's.

### Final Diamond analogy

- Building = **Diamond** (fixed address, basement = storage).  
- Offices = **Facets** (code for each area).  
- Reception directory = **selector → facet table**.  
- Renovating an office = **Replace** in `diamondCut`.  
- Adding a new floor = **Add**.  
- Closing an area = **Remove**.  
- Building floor plan for visitors = **Loupe**.

It is neither bacon nor a lighthouse: it is a **diamond cut into faces**. Each face (facet) reflects a part of the protocol; the whole diamond is what the world sees.

### Is it part of module 11?

No (deliberately excluded in the planning). UUPS + Transparent teach the core of `delegatecall` + storage. Diamond is the next level of modular architecture when the system **does not fit** comfortably in a single impl.

---

## 2. Pattern table (explanation · uses · pros · cons)

### 2.1 Quick view

| Pattern | One line |
|--------|-----------|
| Fixed contract (no proxy) | Address = code = storage; no upgrade |
| "Simple" ERC-1967 | Proxy + impl slot; the base of the others |
| Transparent | Admin vs user in the proxy; upgrade via ProxyAdmin |
| UUPS | Minimal proxy; upgrade in the implementation |
| Beacon | Many proxies; one beacon dictates the impl |
| Minimal proxy (EIP-1167) | Cheap clones of an impl (fixed or via beacon) |
| Diamond (EIP-2535) | One proxy, many facets by selector |
| Metamorphic / CREATE2 | Same address, new bytecode after destroy |

---

### 2.2 Extended table

#### Fixed contract (no proxy)

| | |
|--|--|
| **Technical explanation** | A single bytecode at one address. Storage and logic together. No routing `delegatecall`. |
| **Uses (most common)** | "Immutable" tokens, simple multisigs, scripts, demos, contracts that must be credibly non-upgradeable. |
| **Advantages** | Maximum simplicity; easy to audit; no risk of malicious upgrade; predictable gas. |
| **Disadvantages** | Bug or new feature ⇒ redeploy + migration (social/technical pain). |

#### ERC-1967 Proxy (base)

| | |
|--|--|
| **Technical explanation** | Proxy with `fallback` → `delegatecall` to the address in the canonical slot `eip1967.proxy.implementation`. Avoids collision with the logic's storage. |
| **Uses** | Foundation of Transparent, UUPS, and many libs (OZ). Rarely used "bare" in prod without an upgrade mechanism. |
| **Advantages** | Standard; tools/indexers know the slot; business storage separated from the pointer. |
| **Disadvantages** | It is only the transport; you still need to define *who* can change the slot and how. |

#### Transparent Proxy

| | |
|--|--|
| **Technical explanation** | If `msg.sender == admin` → admin functions (upgrade). Otherwise → `delegatecall` to the impl. Usually paired with `ProxyAdmin` (Ownable2Step). In OZ v5 the admin is usually immutable. |
| **Uses** | Protocols with a team/ops that upgrade without mixing selectors with users; many "classic" OZ projects from before UUPS-first. |
| **Advantages** | Solves function clashes; clear admin/user separation; ops-friendly mental model. |
| **Disadvantages** | Heavier proxy (admin check on every call); deploy + ProxyAdmin; the admin must not use the proxy as a user wallet. |

#### UUPS (ERC-1822)

| | |
|--|--|
| **Technical explanation** | "Dumb" proxy (just slot + `delegatecall`). `upgradeToAndCall` lives in the impl; `_authorizeUpgrade` + `proxiableUUID` prevent upgrades to non-UUPS logic. |
| **Uses** | Current standard for many OZ v5 protocols; when you want a lightweight proxy and auth in the logic. |
| **Advantages** | Less gas/code in the proxy; flexible upgrade; well documented. |
| **Disadvantages** | Upgrading to an impl without UUPS → brick; auth must be maintained in **every** version; selector clashes possible (less drama than Transparent, but it exists in API design). |

#### Beacon Proxy

| | |
|--|--|
| **Technical explanation** | Each instance stores the address of the **beacon**. At runtime: `impl = beacon.implementation()` → `delegatecall(impl)`. Upgrade = `beacon.upgradeTo(newImpl)`. |
| **Uses** | Factories with many instances (vaults, accounts, pool clones); "one logic, N storages". Very common with **clones**. |
| **Advantages** | Mass upgrade in 1 tx; cheaper instance deployment overall; DRY logic. |
| **Disadvantages** | An upgrade bug hits everyone; extra read to the beacon per call; strong centralization in the beacon owner. |

#### Minimal Proxy / Clones (EIP-1167)

| | |
|--|--|
| **Technical explanation** | Minimal bytecode (~45 bytes) that `delegatecall`s to an embedded fixed implementation (or clone+beacon pattern). `CREATE2` is common for predictable addresses. |
| **Uses** | Smart wallets, per-user vaults, Gnosis-style factories, anything that is "a lot of the same". |
| **Advantages** | **Very** cheap deployment per instance; scales to thousands of contracts. |
| **Disadvantages** | A pure clone to a fixed impl does **not** upgrade by itself; for mass upgrades it is combined with **Beacon**. Init must be handled carefully (initializer, no useful constructor). |

#### Diamond (EIP-2535)

| | |
|--|--|
| **Technical explanation** | A proxy (Diamond) maintains `selector → facet`. The fallback `delegatecall`s to the facet. Upgrades via `diamondCut` (Add/Replace/Remove). Shared storage with namespaces (Diamond Storage / AppStorage). Loupe for introspection. |
| **Uses** | Huge modular systems (on-chain games, protocols with many features); less "simple DeFi" than UUPS. |
| **Advantages** | Code scale without a single giant contract; partial upgrades per facet; module-based organization. |
| **Disadvantages** | High complexity (diamond storage, selector clashes, tooling); more expensive audits; steep learning curve. |

#### Metamorphic / CREATE2 + selfdestruct (historical / niche)

| | |
|--|--|
| **Technical explanation** | Same address via `CREATE2`; the code is destroyed and different bytecode is redeployed at the same address. After network changes (deprecation of useful `SELFDESTRUCT`), increasingly less viable. |
| **Uses** | Experiments, some old factories; **not** the recommended path today. |
| **Advantages** | Identical address with new bytecode (in theory). |
| **Disadvantages** | Fragile, dangerous, frowned upon; storage does not "travel" as with a proxy; modern restrictions limit it. |

---

## 3. Which one to choose? (short map)

```
Do you need upgrades?
  NO   → Fixed contract
  YES  → Many instances, same logic?
           YES → Beacon (+ EIP-1167 clones)
           NO  → Separate admin ops / worried about clashes?
                    YES → Transparent
                    NO  → UUPS (modern default "single proxy")
         Huge modular system?
           → Evaluate Diamond (high cost)
```

---

## 4. Beacon and this module (11)

Module 11 implements **UUPS + Transparent** (one proxy, one logic, individual upgrade).

**Beacon** would be the natural next step if the product were:

> "a factory of 500 boxes/vaults; I want to upgrade the logic of all of them at once".

It is not in the v1 scope (see `planificacion-EN.md`: Beacon/Diamond deliberately excluded).

---

## 5. Final analogy (bacon included)

- **UUPS / Transparent:** each house keeps its own blueprint in the drawer; to renovate all the houses, you visit them one by one.  
- **Beacon:** there is a **lighthouse** in town. Every house looks at the lighthouse to know which blueprint to use. Move the lighthouse → they all renovate at once.  
- **Clones:** cheap prefab houses that look at the same blueprint (and often the same lighthouse).  
- **Diamond:** a building with many offices (facets); you renovate floor by floor.

The "bacon" is the lighthouse: it does not store your furniture (storage), it only says **which instruction manual** (implementation) must be followed today.
