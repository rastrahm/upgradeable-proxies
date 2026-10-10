# 11 — Upgradeable Proxies (UUPS & Transparent)

> 🌐 [English](./README-EN.md) · **Español** · [Índice](./README.md)

Proxies upgradeables propios con slots **EIP-1967**, patrones **Transparent** (`ProxyAdmin` Ownable2Step) y **UUPS** (`_authorizeUpgrade`), `Initializable` con storage ERC-7201 y demo `BoxV1 → BoxV2` con `__gap`. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–6** ✅ (contratos + tests + SWC + gas + deploy). **60 tests PASS**.

---

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Librerías | forge-std (proxies, UUPS e `Initializable` implementados en el módulo) |
| Seguridad | Slots EIP-1967, `_disableInitializers()`, custom errors, `__gap`, guard de function clash |

---

## Documentación

| Doc | Descripción |
|-----|-------------|
| [doc/ENTENDER-EL-MODULO-ES.md](./doc/ENTENDER-EL-MODULO-ES.md) | Guía para entender el módulo: decisiones, lógica y gas |
| [doc/STORAGE-SLOTS-ES.md](./doc/STORAGE-SLOTS-ES.md) | Cómo se reparten los slots y por qué no usar el slot 0 |
| [doc/storage-layout-ES.md](./doc/storage-layout-ES.md) | Layout BoxV1/BoxV2 (`forge inspect`) |
| [doc/PATRONES-PROXY-ES.md](./doc/PATRONES-PROXY-ES.md) | Beacon, EIP-1167 (clones) y Diamond (EIP-2535) |
| [doc/MIGRACION-FIJO-A-PROXY-ES.md](./doc/MIGRACION-FIJO-A-PROXY-ES.md) | Migrar un contrato fijo a proxy |
| [doc/GAS-ES.md](./doc/GAS-ES.md) | Optimizaciones de gas y benchmarks |
| [doc/SWC-AUDIT-ES.md](./doc/SWC-AUDIT-ES.md) | Auditoría SWC-100–136 |
| [doc/planificacion-ES.md](./doc/planificacion-ES.md) | Plan, fases y criterios de aceptación |
| [doc/diagrama-de-clases-ES.md](./doc/diagrama-de-clases-ES.md) | UML de contratos |
| [doc/diagrama-de-flujo-ES.md](./doc/diagrama-de-flujo-ES.md) | Flujos de decisión (init, upgrade, routing) |
| [doc/flujograma-ES.md](./doc/flujograma-ES.md) | Flujo actor–sistema extremo a extremo |

---

## Setup

```shell
export PATH="$HOME/.foundry/bin:$PATH"

forge install foundry-rs/forge-std --no-git

forge build
forge test
```

---

## Tests

```shell
forge test --match-contract ERC1967ProxyTest        # 11 PASS
forge test --match-contract TransparentProxyTest    # 11 PASS
forge test --match-contract UUPSTest                # 11 PASS
forge test --match-contract BoxUpgradeTest          # 7 PASS (layout V1 → V2)
forge test --match-contract UpgradeE2ETest          # 3 PASS
forge test --match-path 'test/attack/*'             # 7 PASS (upgrades no autorizados)
forge test --match-path 'test/fuzz/*'               # 4 PASS × 1000 runs
forge test --match-path 'test/gas/*'                # 6 PASS (benchmarks)
```

Validar el layout de storage:

```shell
forge inspect BoxV1 storage-layout
forge inspect BoxV2 storage-layout
```

---

## Deploy (Anvil)

```shell
export PATH="$HOME/.foundry/bin:$PATH"
anvil   # otra terminal

forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
# Opcional: PRIVATE_KEY=0x... INITIAL_VALUE=42
```

Despliega dos stacks de demo:

- **UUPS:** `BoxV1` detrás de `ERC1967Proxy` (inicializado con el deployer como `owner`).
- **Transparent:** `CounterLogic` detrás de `TransparentProxy`, administrado por `ProxyAdmin`.

---

## Estructura

```text
src/
  proxy/            # ERC1967Proxy, TransparentProxy, ProxyAdmin
  uups/             # UUPSUpgradeable
  utils/            # Initializable (ERC-7201)
  implementations/  # BoxV1, BoxV2
  interfaces/       # IBox, IUUPSUpgradeable, ITransparentProxy, ...
  errors/           # ProxyErrors (custom errors)
  mocks/            # Counter*, UUPSCounter*, ClashingLogic, NonUUPSLogic
test/               # Unit, e2e, attack, fuzz y gas
script/             # Deploy.s.sol
doc/                # Documentación ES/EN
portfolio/          # Página de portafolio (ES/EN)
```

---

## Fases

| Fase | Descripción | Estado |
|------|-------------|--------|
| 0 | Setup Foundry + estructura | ✅ |
| 1 | Core ERC-1967 + `delegatecall` | ✅ |
| 2 | Transparent Proxy + `ProxyAdmin` | ✅ |
| 3 | UUPS + `Initializable` | ✅ |
| 4 | BoxV1 / BoxV2 + storage gaps | ✅ |
| 5 | Suite de tests (persistencia, unauthorized, fuzz) | ✅ |
| 6 | Deploy + SWC + optimización de gas | ✅ |
