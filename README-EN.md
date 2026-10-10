# 11 — Upgradeable Proxies (UUPS & Transparent)

> 🌐 **English** · [Español](./README-ES.md) · [Index](./README.md)

Custom upgradeable proxies with **EIP-1967** slots, the **Transparent** pattern (Ownable2Step `ProxyAdmin`) and the **UUPS** pattern (`_authorizeUpgrade`), `Initializable` with ERC-7201 storage, and a `BoxV1 → BoxV2` demo using `__gap`. Solidity `0.8.24` + Foundry.

**Status:** Phases **0–6** ✅ (contracts + tests + SWC + gas + deploy). **60 tests PASS**.

---

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` (pinned pragma) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Libraries | forge-std (proxies, UUPS and `Initializable` implemented in this module) |
| Security | EIP-1967 slots, `_disableInitializers()`, custom errors, `__gap`, function-clash guard |

---

## Documentation

| Doc | Description |
|-----|-------------|
| [doc/ENTENDER-EL-MODULO-EN.md](./doc/ENTENDER-EL-MODULO-EN.md) | Guide to understanding the module: decisions, logic and gas |
| [doc/STORAGE-SLOTS-EN.md](./doc/STORAGE-SLOTS-EN.md) | How storage slots are laid out and why not to use slot 0 |
| [doc/storage-layout-EN.md](./doc/storage-layout-EN.md) | BoxV1/BoxV2 layout (`forge inspect`) |
| [doc/PATRONES-PROXY-EN.md](./doc/PATRONES-PROXY-EN.md) | Beacon, EIP-1167 (clones) and Diamond (EIP-2535) |
| [doc/MIGRACION-FIJO-A-PROXY-EN.md](./doc/MIGRACION-FIJO-A-PROXY-EN.md) | Migrating a fixed contract to a proxy |
| [doc/GAS-EN.md](./doc/GAS-EN.md) | Gas optimizations and benchmarks |
| [doc/SWC-AUDIT-EN.md](./doc/SWC-AUDIT-EN.md) | SWC-100–136 audit |
| [doc/planificacion-EN.md](./doc/planificacion-EN.md) | Plan, phases and acceptance criteria |
| [doc/diagrama-de-clases-EN.md](./doc/diagrama-de-clases-EN.md) | Contract UML |
| [doc/diagrama-de-flujo-EN.md](./doc/diagrama-de-flujo-EN.md) | Decision flows (init, upgrade, routing) |
| [doc/flujograma-EN.md](./doc/flujograma-EN.md) | End-to-end actor–system flowchart |

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
forge test --match-contract BoxUpgradeTest          # 7 PASS (V1 → V2 layout)
forge test --match-contract UpgradeE2ETest          # 3 PASS
forge test --match-path 'test/attack/*'             # 7 PASS (unauthorized upgrades)
forge test --match-path 'test/fuzz/*'               # 4 PASS × 1000 runs
forge test --match-path 'test/gas/*'                # 6 PASS (benchmarks)
```

Validate the storage layout:

```shell
forge inspect BoxV1 storage-layout
forge inspect BoxV2 storage-layout
```

---

## Deploy (Anvil)

```shell
export PATH="$HOME/.foundry/bin:$PATH"
anvil   # another terminal

forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
# Optional: PRIVATE_KEY=0x... INITIAL_VALUE=42
```

Deploys two demo stacks:

- **UUPS:** `BoxV1` behind `ERC1967Proxy` (initialized with the deployer as `owner`).
- **Transparent:** `CounterLogic` behind `TransparentProxy`, managed by `ProxyAdmin`.

---

## Structure

```text
src/
  proxy/            # ERC1967Proxy, TransparentProxy, ProxyAdmin
  uups/             # UUPSUpgradeable
  utils/            # Initializable (ERC-7201)
  implementations/  # BoxV1, BoxV2
  interfaces/       # IBox, IUUPSUpgradeable, ITransparentProxy, ...
  errors/           # ProxyErrors (custom errors)
  mocks/            # Counter*, UUPSCounter*, ClashingLogic, NonUUPSLogic
test/               # Unit, e2e, attack, fuzz and gas
script/             # Deploy.s.sol
doc/                # ES/EN documentation
portfolio/          # Portfolio page (ES/EN)
```

---

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Foundry setup + structure | ✅ |
| 1 | ERC-1967 core + `delegatecall` | ✅ |
| 2 | Transparent Proxy + `ProxyAdmin` | ✅ |
| 3 | UUPS + `Initializable` | ✅ |
| 4 | BoxV1 / BoxV2 + storage gaps | ✅ |
| 5 | Test suite (persistence, unauthorized, fuzz) | ✅ |
| 6 | Deploy + SWC + gas optimization | ✅ |
