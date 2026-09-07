# Flujograma — Ciclo completo de proxies upgradeables

Flujo extremo a extremo entre actores y contratos: despliegue, uso, upgrade y verificación de persistencia.

## Actores

| Actor | Rol |
|-------|-----|
| Deployer | Despliega impl, proxy y (si aplica) `ProxyAdmin` |
| Owner / Admin | Autoriza upgrades (`ProxyAdmin.owner` o `_authorizeUpgrade`) |
| Usuario | Llama funciones de negocio a través del proxy |
| Proxy | Guarda slots EIP-1967; enruta con `delegatecall` |
| Implementation V1 / V2 | Lógica; storage layout compatible |
| Tester / CI | Foundry: unit, unauthorized, fuzz, `forge inspect` |

---

## Flujograma principal — Deploy → Use → Upgrade → Verify

```mermaid
flowchart TD
    Start([Inicio]) --> DeployImpl[Deploy BoxV1 implementation]
    DeployImpl --> Disable[Constructor: _disableInitializers]
    Disable --> DeployProxy{¿Patrón?}

    DeployProxy -->|Transparent| DepAdmin[Deploy ProxyAdmin]
    DepAdmin --> DepTP[Deploy TransparentProxy\nimpl=V1, admin=ProxyAdmin, data=initialize]
    DeployProxy -->|UUPS| DepUUPS[Deploy ERC1967Proxy\nimpl=V1, data=initialize]

    DepTP --> Ready[Proxy listo — estado inicializado]
    DepUUPS --> Ready

    Ready --> UserCall[Usuario: store / retrieve vía proxy]
    UserCall --> StateOnProxy[Estado escrito en storage del PROXY]
    StateOnProxy --> UpgradeIntent[Admin inicia upgrade a BoxV2]

    UpgradeIntent --> Auth{¿Caller autorizado?}
    Auth -->|No| Rej[Revert UnauthorizedUpgrade]
    Auth -->|Sí| Valid{¿Nueva impl válida?}
    Valid -->|No| RejImpl[Revert InvalidImplementation]
    Valid -->|Sí| WriteSlot[Actualizar IMPLEMENTATION_SLOT → V2]
    WriteSlot --> Migrate[Opcional: upgradeToAndCall data\ninitializeV2 / migración]
    Migrate --> Verify[retrieve / lecturas == estado previo]
    Verify --> NewLogic[Nuevas funciones V2 disponibles]
    NewLogic --> End([Fin — upgrade exitoso])

    Rej --> EndFail([Fin — rechazo])
    RejImpl --> EndFail
```

---

## Flujograma Transparent — admin vs usuario

```mermaid
flowchart TD
    A[Tx hacia TransparentProxy] --> B{msg.sender == admin?}
    B -->|Sí| C[Path admin:\nupgradeToAndCall / changeAdmin]
    C --> D[No ejecuta lógica Box\ncomo si fuera usuario]
    B -->|No| E[Path usuario]
    E --> F[delegatecall → BoxVn]
    F --> G[Efectos en storage del proxy]
    D --> H([Respuesta admin])
    G --> I([Respuesta negocio])
```

---

## Flujograma UUPS — autorización en la lógica

```mermaid
flowchart TD
    U[Usuario o owner llama\nupgradeToAndCall en el PROXY] --> D[delegatecall a impl actual]
    D --> A[_authorizeUpgrade newImpl]
    A --> OK{¿owner / rol OK?}
    OK -->|No| X[UnauthorizedUpgrade]
    OK -->|Sí| P[Comprobar proxiableUUID /\ncódigo en newImpl]
    P --> V{¿válida?}
    V -->|No| I[InvalidImplementation]
    V -->|Sí| S[IMPLEMENTATION_SLOT = newImpl]
    S --> C[Si data.length > 0:\ndelegatecall data en nuevo contexto]
    C --> Done([Upgrade OK])
```

---

## Flujograma anti corrupción de storage

```mermaid
flowchart TD
    A[Estado V1: slots 0..n ocupados] --> B[Diseñar BoxV2]
    B --> C{¿Reordena o reutiliza slots?}
    C -->|Sí| D[PROHIBIDO — colisión]
    C -->|No| E[Añadir vars al final /\nreducir __gap]
    E --> F[forge inspect storage-layout]
    F --> G{¿Offsets V1 ⊆ V2?}
    G -->|No| H[Ajustar diseño]
    H --> B
    G -->|Sí| I[Test: fuzz valores → upgrade → assert]
    I --> J{¿Datos intactos?}
    J -->|No| K[Fallo de layout / bug]
    J -->|Sí| L[Layout compatible]
    D --> K
```

---

## Secuencia — Transparent (ejemplo)

```mermaid
sequenceDiagram
    autonumber
    actor D as Deployer / Owner
    actor U as Usuario
    participant Impl as BoxV1
    participant Admin as ProxyAdmin
    participant P as TransparentProxy
    participant V2 as BoxV2

    D->>Impl: deploy BoxV1
    Note over Impl: _disableInitializers()
    D->>Admin: deploy ProxyAdmin(owner)
    D->>P: deploy(impl, admin, initData)
    P->>Impl: delegatecall initialize(...)
    Note over P: estado owner/value en P

    U->>P: store(42)
    P->>Impl: delegatecall store(42)
    Note over P: value = 42

    D->>Admin: upgradeAndCall(P, V2, initV2Data)
    Admin->>P: upgradeToAndCall(V2, data)\n(msg.sender = Admin)
    Note over P: IMPLEMENTATION_SLOT = V2
    P->>V2: delegatecall initV2 / migración

    U->>P: retrieve()
    P->>V2: delegatecall retrieve()
    V2-->>U: 42 (persistido)
```

---

## Secuencia — UUPS (ejemplo)

```mermaid
sequenceDiagram
    autonumber
    actor O as Owner
    actor U as Usuario
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

## Resumen operativo

1. **Deploy de la impl** siempre con inicializadores deshabilitados en constructor.
2. **Initialize solo vía proxy** (calldata del constructor del proxy o llamada posterior controlada).
3. **Usuario habla con el proxy**, nunca necesita conocer la dirección de la impl (salvo operación/ops).
4. **Upgrade = cambiar un slot EIP-1967** (+ autorización); el storage de negocio permanece.
5. **Tests Foundry** deben recorrer este flujograma y los caminos `UnauthorizedUpgrade`, `AlreadyInitialized`, `InvalidImplementation`, `DelegateCallFailed`.
