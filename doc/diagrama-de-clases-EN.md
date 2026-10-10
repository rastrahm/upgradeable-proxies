# Class diagram — Upgradeable Proxies (UUPS & Transparent)

> 🌐 **English** · [Español](./diagrama-de-clases-ES.md) · [Index](../README.md)

Structural view of contracts, interfaces, and relationships (module 11).

## Diagram (Mermaid)

```mermaid
classDiagram
    direction TB

    class IERC1967 {
        <<interface>>
        +Upgraded(implementation)
        +AdminChanged(previousAdmin, newAdmin)
    }

    class ITransparentProxy {
        <<interface>>
        +admin() address
        +implementation() address
        +changeAdmin(newAdmin)
        +upgradeToAndCall(newImplementation, data)
    }

    class IUUPSUpgradeable {
        <<interface>>
        +proxiableUUID() bytes32
        +upgradeToAndCall(newImplementation, data)
    }

    class IBox {
        <<interface>>
        +initialize(owner, initialValue)
        +store(newValue)
        +retrieve() uint256
        +version() string
    }

    class Initializable {
        <<abstract>>
        -uint64 _initialized
        -bool _initializing
        +initializer()
        +reinitializer(version)
        #_disableInitializers()
        #_getInitializedVersion() uint64
    }

    class ERC1967Proxy {
        <<contract>>
        +constructor(implementation, data)
        #_implementation() address
        #_setImplementation(newImplementation)
        #_delegate(implementation)
        +fallback()
        +receive()
    }

    class TransparentProxy {
        <<contract>>
        +constructor(implementation, admin, data)
        #_admin() address
        #_setAdmin(newAdmin)
        +fallback()
    }

    class ProxyAdmin {
        <<contract>>
        +owner() address
        +getProxyImplementation(proxy) address
        +getProxyAdmin(proxy) address
        +changeProxyAdmin(proxy, newAdmin)
        +upgradeAndCall(proxy, implementation, data)
    }

    class UUPSUpgradeable {
        <<abstract>>
        +proxiableUUID() bytes32
        +upgradeToAndCall(newImplementation, data)
        #_authorizeUpgrade(newImplementation)*
        #_upgradeToAndCallUUPS(newImplementation, data)
    }

    class BoxV1 {
        <<implementation>>
        -address owner
        -uint256 value
        -uint256[50] __gap
        +initialize(owner_, initialValue)
        +store(newValue)
        +retrieve() uint256
        +version() string
        #_authorizeUpgrade(newImplementation)
    }

    class BoxV2 {
        <<implementation>>
        -address owner
        -uint256 value
        -string label
        -uint256[49] __gap
        +initializeV2(label_)
        +store(newValue)
        +retrieve() uint256
        +version() string
        +setLabel(label_)
        #_authorizeUpgrade(newImplementation)
    }

    class EIP1967Slots {
        <<library / constants>>
        IMPLEMENTATION_SLOT
        ADMIN_SLOT
    }

    IERC1967 <|.. ERC1967Proxy
    ERC1967Proxy <|-- TransparentProxy
    ITransparentProxy <|.. TransparentProxy
    IUUPSUpgradeable <|.. UUPSUpgradeable
    Initializable <|-- UUPSUpgradeable
    UUPSUpgradeable <|-- BoxV1
    UUPSUpgradeable <|-- BoxV2
    Initializable <|-- BoxV1
    Initializable <|-- BoxV2
    IBox <|.. BoxV1
    IBox <|.. BoxV2

    TransparentProxy o-- ProxyAdmin : admin EIP-1967
    ERC1967Proxy ..> EIP1967Slots : reads/writes slots
    TransparentProxy ..> EIP1967Slots : admin + impl
    ProxyAdmin ..> TransparentProxy : upgradeAndCall
    TransparentProxy ..> BoxV1 : delegatecall
    TransparentProxy ..> BoxV2 : delegatecall post-upgrade
    BoxV1 ..> BoxV2 : logic upgrade\n(same proxy storage)
```

## Key relationships

| From | To | Type | Reason |
|-------|-------|------|--------|
| `ERC1967Proxy` | Implementation | Dependency (delegatecall) | Executes logic in the proxy's storage context |
| `TransparentProxy` | `ProxyAdmin` | Association (admin slot) | Only the admin manages upgrades / changeAdmin |
| `ProxyAdmin` | `TransparentProxy` | Dependency | Calls `upgradeToAndCall` as `msg.sender == admin` |
| `BoxV1` / `BoxV2` | `UUPSUpgradeable` | Inheritance | Upgrade authorization lives in the logic |
| `BoxV*` | `Initializable` | Inheritance | Prevents re-init and disables constructors that would be useful via proxy |
| `BoxV1` → `BoxV2` | — | Layout compatibility | New variables only at the end; reduced `__gap` |

## Design notes

1. **Two upgrade paths**: Transparent (admin in the proxy) vs UUPS (authorization in the impl).
2. **Proxy storage ≠ deployed impl storage**: state lives at the proxy's address.
3. **`__gap`**: reserves slots in base/impl contracts for future extensions without collisions.
4. **Function clash (Transparent)**: if `msg.sender` is the admin, user selectors are not delegatecalled.
5. **OZ v5**: audited primitives can be inherited; the semantics must comply with EIP-1967 and the module's custom errors.
