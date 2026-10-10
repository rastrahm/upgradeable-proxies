# Flowchart — Full lifecycle of upgradeable proxies

> 🌐 **English** · [Español](./flujograma-ES.md) · [Index](../README.md)

End-to-end flow between actors and contracts: deployment, usage, upgrade, and persistence verification.

## Actors

| Actor | Role |
|-------|-----|
| Deployer | Deploys impl, proxy and (if applicable) `ProxyAdmin` |
| Owner / Admin | Authorizes upgrades (`ProxyAdmin.owner` or `_authorizeUpgrade`) |
| User | Calls business functions through the proxy |
| Proxy | Stores EIP-1967 slots; routes with `delegatecall` |
| Implementation V1 / V2 | Logic; compatible storage layout |
| Tester / CI | Foundry: unit, unauthorized, fuzz, `forge inspect` |

---

## Main flowchart — Deploy → Use → Upgrade → Verify

```mermaid
flowchart TD
    Start([Start]) --> DeployImpl[Deploy BoxV1 implementation]
    DeployImpl --> Disable[Constructor: _disableInitializers]
    Disable --> DeployProxy{Pattern?}

    DeployProxy -->|Transparent| DepAdmin[Deploy ProxyAdmin]
    DepAdmin --> DepTP[Deploy TransparentProxy\nimpl=V1, admin=ProxyAdmin, data=initialize]
    DeployProxy -->|UUPS| DepUUPS[Deploy ERC1967Proxy\nimpl=V1, data=initialize]

    DepTP --> Ready[Proxy ready — state initialized]
    DepUUPS --> Ready

    Ready --> UserCall[User: store / retrieve via proxy]
    UserCall --> StateOnProxy[State written to the PROXY storage]
    StateOnProxy --> UpgradeIntent[Admin starts upgrade to BoxV2]

    UpgradeIntent --> Auth{Authorized caller?}
    Auth -->|No| Rej[Revert UnauthorizedUpgrade]
    Auth -->|Yes| Valid{Valid new impl?}
    Valid -->|No| RejImpl[Revert InvalidImplementation]
    Valid -->|Yes| WriteSlot[Update IMPLEMENTATION_SLOT → V2]
    WriteSlot --> Migrate[Optional: upgradeToAndCall data\ninitializeV2 / migration]
    Migrate --> Verify[retrieve / reads == previous state]
    Verify --> NewLogic[New V2 functions available]
    NewLogic --> End([End — successful upgrade])

    Rej --> EndFail([End — rejected])
    RejImpl --> EndFail
```

---

## Transparent flowchart — admin vs user

```mermaid
flowchart TD
    A[Tx to TransparentProxy] --> B{msg.sender == admin?}
    B -->|Yes| C[Admin path:\nupgradeToAndCall / changeAdmin]
    C --> D[Does not execute Box logic\nas if it were a user]
    B -->|No| E[User path]
    E --> F[delegatecall → BoxVn]
    F --> G[Effects on the proxy storage]
    D --> H([Admin response])
    G --> I([Business response])
```

---

## UUPS flowchart — authorization in the logic

```mermaid
flowchart TD
    U[User or owner calls\nupgradeToAndCall on the PROXY] --> D[delegatecall to current impl]
    D --> A[_authorizeUpgrade newImpl]
    A --> OK{owner / role OK?}
    OK -->|No| X[UnauthorizedUpgrade]
    OK -->|Yes| P[Check proxiableUUID /\ncode at newImpl]
    P --> V{valid?}
    V -->|No| I[InvalidImplementation]
    V -->|Yes| S[IMPLEMENTATION_SLOT = newImpl]
    S --> C[If data.length > 0:\ndelegatecall data in new context]
    C --> Done([Upgrade OK])
```

---

## Storage anti-corruption flowchart

```mermaid
flowchart TD
    A[V1 state: slots 0..n occupied] --> B[Design BoxV2]
    B --> C{Reorders or reuses slots?}
    C -->|Yes| D[FORBIDDEN — collision]
    C -->|No| E[Append vars at the end /\nshrink __gap]
    E --> F[forge inspect storage-layout]
    F --> G{V1 offsets ⊆ V2?}
    G -->|No| H[Adjust design]
    H --> B
    G -->|Yes| I[Test: fuzz values → upgrade → assert]
    I --> J{Data intact?}
    J -->|No| K[Layout failure / bug]
    J -->|Yes| L[Compatible layout]
    D --> K
```

---

## Sequence — Transparent (example)

```mermaid
sequenceDiagram
    autonumber
    actor D as Deployer / Owner
    actor U as User
    participant Impl as BoxV1
    participant Admin as ProxyAdmin
    participant P as TransparentProxy
    participant V2 as BoxV2

    D->>Impl: deploy BoxV1
    Note over Impl: _disableInitializers()
    D->>Admin: deploy ProxyAdmin(owner)
    D->>P: deploy(impl, admin, initData)
    P->>Impl: delegatecall initialize(...)
    Note over P: owner/value state in P

    U->>P: store(42)
    P->>Impl: delegatecall store(42)
    Note over P: value = 42

    D->>Admin: upgradeAndCall(P, V2, initV2Data)
    Admin->>P: upgradeToAndCall(V2, data)\n(msg.sender = Admin)
    Note over P: IMPLEMENTATION_SLOT = V2
    P->>V2: delegatecall initV2 / migration

    U->>P: retrieve()
    P->>V2: delegatecall retrieve()
    V2-->>U: 42 (persisted)
```

---

## Sequence — UUPS (example)

```mermaid
sequenceDiagram
    autonumber
    actor O as Owner
    actor U as User
    participant V1 as BoxV1
    participant P as ERC1967Proxy
    participant V2 as BoxV2

    O->>V1: deploy
    O->>P: deploy(V1, initialize data)
    P->>V1: delegatecall initialize

    U->>P: store(7)
    P->>V1: delegatecall store

    O->>P: upgradeToAndCall(V2, data)
    P->>V1: delegatecall upgradeToAndCall
    V1->>V1: _authorizeUpgrade(V2)
    Note over P: slot → V2

    U->>P: retrieve()
    P->>V2: delegatecall retrieve
    V2-->>U: 7
```

---

## Operational summary

1. **Deploy the impl** always with initializers disabled in the constructor.
2. **Initialize only via the proxy** (proxy constructor calldata or a controlled later call).
3. **The user talks to the proxy** and never needs to know the impl address (except for operations/ops).
4. **Upgrade = changing an EIP-1967 slot** (+ authorization); business storage remains intact.
5. **Foundry tests** must walk through this flowchart and the `UnauthorizedUpgrade`, `AlreadyInitialized`, `InvalidImplementation`, `DelegateCallFailed` paths.
