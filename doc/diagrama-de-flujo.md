# Diagrama de flujo — Routing, inicialización y upgrade

Flujos de decisión internos del sistema de proxies (módulo 11).

## 1. Routing Transparent Proxy (fallback)

```mermaid
flowchart TD
    A[Llegada de calldata al proxy] --> B{¿msg.sender == admin?}
    B -->|Sí| C{¿Selector de admin?\nupgrade / changeAdmin / …}
    C -->|Sí| D[Ejecutar lógica admin\nen el proxy]
    C -->|No / selector vacío| E[Comportamiento admin\ndefinido — sin delegatecall usuario]
    B -->|No| F[Leer IMPLEMENTATION_SLOT]
    F --> G{¿implementation != 0?}
    G -->|No| H[Revert InvalidImplementation]
    G -->|Sí| I[delegatecall a implementation]
    I --> J{¿success?}
    J -->|No| K[Revert DelegateCallFailed]
    J -->|Sí| L[Return returndata al caller]
    D --> M[Fin]
    E --> M
    L --> M
    H --> M
    K --> M
```

## 2. Routing UUPS (usuario siempre delegatecall)

```mermaid
flowchart TD
    A[Calldata al proxy UUPS/ERC1967] --> B[Leer IMPLEMENTATION_SLOT]
    B --> C{¿implementation válida?}
    C -->|No| D[InvalidImplementation]
    C -->|Sí| E[delegatecall]
    E --> F{¿Selector es upgradeToAndCall?}
    F -->|No| G[Lógica de negocio Box]
    F -->|Sí| H[_authorizeUpgrade]
    H --> I{¿autorizado?}
    I -->|No| J[UnauthorizedUpgrade]
    I -->|Sí| K[Validar nueva impl +\nproxiableUUID / código]
    K --> L{¿válida?}
    L -->|No| M[InvalidImplementation]
    L -->|Sí| N[Escribir nuevo IMPLEMENTATION_SLOT]
    N --> O[Opcional: delegatecall data de init/migración]
    G --> P[Fin OK]
    O --> P
```

## 3. Inicialización (`Initializable`)

```mermaid
stateDiagram-v2
    [*] --> Uninitialized: deploy impl +\n_disableInitializers en constructor

    note right of Uninitialized
      La impl “sola” no debe
      poder inicializarse de forma
      usable como proxy storage.
    end note

    Uninitialized --> Initializing: initialize() vía proxy\n(modifier initializer)
    Initializing --> Initialized: fin de initialize
    Initialized --> Reverting: segundo initialize()
    Reverting --> Initialized: AlreadyInitialized

    Initialized --> Reinitializing: reinitializer(v2)\npost-upgrade opcional
    Reinitializing --> InitializedV2: initializeV2 OK
```

## 4. Ciclo de upgrade (ambos patrones)

```mermaid
stateDiagram-v2
    [*] --> V1Active: Proxy apunta a BoxV1\n+ initialize hecho

    V1Active --> Mutated: store / lógica usuario\n(estado en storage del proxy)

    Mutated --> UpgradeCheck: upgradeToAndCall(V2, data)
    UpgradeCheck --> Rejected: no admin / no _authorizeUpgrade
    Rejected --> Mutated: UnauthorizedUpgrade

    UpgradeCheck --> V2Active: slot impl = BoxV2\n+ data de migración OK

    V2Active --> StatePreserved: retrieve() == valor previo
    StatePreserved --> [*]
```

## 5. Tabla de decisiones / errores

| Situación | Condición | Resultado | Error |
|-----------|-----------|-----------|--------|
| Delegatecall a `address(0)` | impl inválida | revert | `InvalidImplementation` |
| `delegatecall` falla | success == false | revert | `DelegateCallFailed` |
| Re-init | `_initialized` ya set | revert | `AlreadyInitialized` |
| Upgrade sin permiso | caller no autorizado | revert | `UnauthorizedUpgrade` |
| Upgrade a impl sin código / UUID malo | check UUPS/ERC1967 | revert | `InvalidImplementation` |
| Usuario en Transparent | `msg.sender != admin` | delegatecall | — |
| Admin en Transparent | `msg.sender == admin` | path admin | — |

## Invariantes

1. El **estado de negocio** vive en la dirección del **proxy**, nunca se “mueve” al cambiar de impl.
2. Toda ejecución de lógica de usuario pasa por **`delegatecall`**.
3. Un upgrade **no** re-ejecuta `initialize` de V1; migraciones usan `reinitializer` o calldata de `upgradeToAndCall`.
4. Layout V2 **no reordena ni reutiliza** slots ya ocupados por V1.
