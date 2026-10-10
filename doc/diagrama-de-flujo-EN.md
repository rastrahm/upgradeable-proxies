# Flow Diagram — Routing, Initialization and Upgrade

> 🌐 **English** · [Español](./diagrama-de-flujo-ES.md) · [Index](../README.md)

Internal decision flows of the proxy system (module 11).

## 1. Transparent Proxy Routing (fallback)

```mermaid
flowchart TD
    A[Calldata arrives at the proxy] --> B{msg.sender == admin?}
    B -->|Yes| C{Admin selector?\nupgrade / changeAdmin / …}
    C -->|Yes| D[Execute admin logic\nin the proxy]
    C -->|No / empty selector| E[Defined admin behavior\n— no user delegatecall]
    B -->|No| F[Read IMPLEMENTATION_SLOT]
    F --> G{implementation != 0?}
    G -->|No| H[Revert InvalidImplementation]
    G -->|Yes| I[delegatecall to implementation]
    I --> J{success?}
    J -->|No| K[Revert DelegateCallFailed]
    J -->|Yes| L[Return returndata to the caller]
    D --> M[End]
    E --> M
    L --> M
    H --> M
    K --> M
```

## 2. UUPS Routing (user always delegatecalls)

```mermaid
flowchart TD
    A[Calldata to the UUPS/ERC1967 proxy] --> B[Read IMPLEMENTATION_SLOT]
    B --> C{Valid implementation?}
    C -->|No| D[InvalidImplementation]
    C -->|Yes| E[delegatecall]
    E --> F{Is the selector upgradeToAndCall?}
    F -->|No| G[Box business logic]
    F -->|Yes| H[_authorizeUpgrade]
    H --> I{Authorized?}
    I -->|No| J[UnauthorizedUpgrade]
    I -->|Yes| K[Validate new impl +\nproxiableUUID / code]
    K --> L{Valid?}
    L -->|No| M[InvalidImplementation]
    L -->|Yes| N[Write new IMPLEMENTATION_SLOT]
    N --> O[Optional: delegatecall init/migration data]
    G --> P[End OK]
    O --> P
```

## 3. Initialization (`Initializable`)

```mermaid
stateDiagram-v2
    [*] --> Uninitialized: deploy impl +\n_disableInitializers in constructor

    note right of Uninitialized
      The standalone impl must not
      be initializable in a way that
      is usable as proxy storage.
    end note

    Uninitialized --> Initializing: initialize() via proxy\n(initializer modifier)
    Initializing --> Initialized: end of initialize
    Initialized --> Reverting: second initialize()
    Reverting --> Initialized: AlreadyInitialized

    Initialized --> Reinitializing: reinitializer(v2)\noptional post-upgrade
    Reinitializing --> InitializedV2: initializeV2 OK
```

## 4. Upgrade Lifecycle (both patterns)

```mermaid
stateDiagram-v2
    [*] --> V1Active: Proxy points to BoxV1\n+ initialize done

    V1Active --> Mutated: store / user logic\n(state in proxy storage)

    Mutated --> UpgradeCheck: upgradeToAndCall(V2, data)
    UpgradeCheck --> Rejected: not admin / no _authorizeUpgrade
    Rejected --> Mutated: UnauthorizedUpgrade

    UpgradeCheck --> V2Active: impl slot = BoxV2\n+ migration data OK

    V2Active --> StatePreserved: retrieve() == previous value
    StatePreserved --> [*]
```

## 5. Decision / Error Table

| Situation | Condition | Result | Error |
|-----------|-----------|-----------|--------|
| Delegatecall to `address(0)` | invalid impl | revert | `InvalidImplementation` |
| `delegatecall` fails | success == false | revert | `DelegateCallFailed` |
| Re-init | `_initialized` already set | revert | `AlreadyInitialized` |
| Upgrade without permission | unauthorized caller | revert | `UnauthorizedUpgrade` |
| Upgrade to impl without code / bad UUID | UUPS/ERC1967 check | revert | `InvalidImplementation` |
| User on Transparent | `msg.sender != admin` | delegatecall | — |
| Admin on Transparent | `msg.sender == admin` | admin path | — |

## Invariants

1. The **business state** lives at the **proxy** address; it never “moves” when the impl changes.
2. All user logic execution goes through **`delegatecall`**.
3. An upgrade does **not** re-run V1's `initialize`; migrations use `reinitializer` or `upgradeToAndCall` calldata.
4. The V2 layout does **not reorder or reuse** slots already occupied by V1.
