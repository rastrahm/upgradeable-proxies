# Diagrama de clases — Upgradeable Proxies (UUPS & Transparent)

Vista estructural de contratos, interfaces y relaciones (módulo 11).

## Diagrama (Mermaid)

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
    ERC1967Proxy ..> EIP1967Slots : lee/escribe slots
    TransparentProxy ..> EIP1967Slots : admin + impl
    ProxyAdmin ..> TransparentProxy : upgradeAndCall
    TransparentProxy ..> BoxV1 : delegatecall
    TransparentProxy ..> BoxV2 : delegatecall post-upgrade
    BoxV1 ..> BoxV2 : upgrade de lógica\n(mismo storage proxy)
```

## Relaciones clave

| Desde | Hacia | Tipo | Motivo |
|-------|-------|------|--------|
| `ERC1967Proxy` | Implementación | Dependencia (delegatecall) | Ejecuta lógica en contexto de storage del proxy |
| `TransparentProxy` | `ProxyAdmin` | Asociación (slot admin) | Solo el admin gestiona upgrades / changeAdmin |
| `ProxyAdmin` | `TransparentProxy` | Dependencia | Llama `upgradeToAndCall` como `msg.sender == admin` |
| `BoxV1` / `BoxV2` | `UUPSUpgradeable` | Herencia | La autorización de upgrade vive en la lógica |
| `BoxV*` | `Initializable` | Herencia | Evita re-init y deshabilita constructores útiles vía proxy |
| `BoxV1` → `BoxV2` | — | Compatibilidad de layout | Variables nuevas solo al final; `__gap` reducido |

## Notas de diseño

1. **Dos caminos de upgrade**: Transparent (admin en el proxy) vs UUPS (autorización en la impl).
2. **Storage del proxy ≠ storage de la impl desplegada**: el estado vive en la dirección del proxy.
3. **`__gap`**: reserva slots en contratos base/impl para extensiones futuras sin colisión.
4. **Function clash (Transparent)**: si `msg.sender` es admin, no se hace delegatecall de selectores de usuario.
5. **OZ v5**: se puede heredar primitivas auditadas; la semántica debe cumplir EIP-1967 y los errores custom del módulo.
