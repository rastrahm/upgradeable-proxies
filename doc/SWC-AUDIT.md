# Auditoría SWC — Upgradeable Proxies (UUPS & Transparent)

Verificación de proxies EIP-1967, Transparent/`ProxyAdmin`, UUPS/`Initializable` y Box V1/V2 contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, pragma fijo, access control, gaps de storage).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados (prod / core):**  
`src/proxy/ERC1967Proxy.sol`, `src/proxy/TransparentProxy.sol`, `src/proxy/ProxyAdmin.sol`,  
`src/uups/UUPSUpgradeable.sol`, `src/utils/Initializable.sol`,  
`src/implementations/BoxV1.sol`, `src/implementations/BoxV2.sol` (+ interfaces / errores)

**Mocks (fuera de prod):** `src/mocks/*`  
**Fecha:** 2026-09-08  
**Referencia tests:** `test/ERC1967Proxy.t.sol`, `test/TransparentProxy.t.sol`, `test/UUPS.t.sol`, `test/BoxUpgrade.t.sol`, `test/UpgradeE2E.t.sol`, `test/fuzz/`, `test/attack/`  
**Estilo:** alineado a [`10-dao-governance/doc/SWC-AUDIT.md`](../../10-dao-governance/doc/SWC-AUDIT.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 31 |
| ⚠️ Informativo (diseño / trust / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1 (ERC-1967 + Transparent + UUPS + Box demo). El módulo **usa `delegatecall` de forma intencional** (SWC-112): el riesgo se mitiga con slots EIP-1967, validación de implementación, `_authorizeUpgrade` / `ProxyAdmin`, `_disableInitializers` y gaps de layout. Riesgos informativos: centralización del `owner`/`ProxyAdmin`, upgrades a impl maliciosa si el autorizado es comprometido, y selector clash operativo si el admin EOA usa el proxy como wallet de usuario.

**Principios del suite verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `ProxyErrors` |
| Pragma fijo `0.8.24` | ✅ |
| EIP-1967 implementation / admin slots | ✅ + unit |
| Initializers deshabilitados en impl | ✅ + attack |
| Access control de upgrades | ✅ Transparent `Ownable2Step` + UUPS owner |
| Storage gaps / layout V1→V2 | ✅ `forge inspect` + `doc/storage-layout.md` |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |
| Attack suite unauthorized | ✅ `test/attack/` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en Upgradeable Proxies |
|----|--------|--------|--------|----------------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; fuzz de `value` con `bound` |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | `delegatecall` chequea `success`; bubble returndata o `DelegateCallFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Parcial | ✅ | Proxy `payable` solo para reenviar `msg.value` vía `delegatecall`; sin withdraw libre |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Parcial | ✅ | Upgrades atómicos (tx revierte si falla); sin callbacks externos de negocio en core; attack auth |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `public` / `private` / `constant` / `immutable` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | Sí | ✅ | `delegatecall` solo a impl del slot EIP-1967; upgrade exige auth + código + (UUPS) `proxiableUUID` |
| SWC-113 | DoS with Failed Call | Sí | ✅ | Fallo de `delegatecall` → revert (`DelegateCallFailed` / bubble); estado de upgrade no queda a medias si revierte la tx |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Front-run de `upgradeToAndCall` si el owner firma/envía en mempool; ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth por `msg.sender` (owner / ProxyAdmin) |
| SWC-116 | Block values as a proxy for time | No | N/A | Sin delays temporales on-chain en v1 |
| SWC-117 | Signature Malleability | No | N/A | Sin firmas / `ecrecover` |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing de estado en core |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | Sin firmas |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | Sin verificación de firmas |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit/e2e/fuzz/attack |
| SWC-124 | Write to Arbitrary Storage Location | Parcial | ✅ | Assembly escribe solo slots EIP-1967 conocidos / calldata copy; negocio en layout tipado + `__gap` |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `Initializable` + `UUPSUpgradeable` + `IBox` en Box; Transparent extiende ERC1967 |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | `upgradeToAndCall` con `data` arbitrario puede OOG; acotado por el caller autorizado |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ⚠️ | Init/migración pesada en `data` puede OOG (ops) |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII en `src/` |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin dead code material en core |
| SWC-132 | Unexpected Ether balance | Parcial | ✅ | ETH en proxy es saldo del proxy; lógica debe manejar `msg.value` vía impl |
| SWC-133 | Hash Collisions (var-length args) | No | N/A | Slots EIP-1967 con `keccak256` de strings fijos |
| SWC-134 | Message call with hardcoded gas | No | N/A | Sin `{gas: …}` |
| SWC-135 | Code With No Effects | No | N/A | Sin no-ops relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Storage del proxy es público por diseño |

---

## Riesgos informativos

### SWC-112 — `delegatecall` (diseño del módulo)

Todo el patrón proxy **depende** de `delegatecall`. Mitigaciones v1:

1. Solo se delega a la dirección del slot EIP-1967.
2. Set de impl exige `code.length > 0` (`InvalidImplementation`).
3. UUPS: `proxiableUUID` debe devolver el slot EIP-1967.
4. Upgrades solo con `_authorizeUpgrade` (owner) o `ProxyAdmin.onlyOwner`.
5. Implementaciones llaman `_disableInitializers()` en constructor.

Un owner comprometido puede apuntar a una impl maliciosa: es riesgo de **trust/key**, no de bypass anónimo.

### SWC-114 — Orden / front-run de upgrade

`upgradeToAndCall` en mempool puede ser front-runeado (misma auth). Mitigación operativa: private relay / multisig / timelock (fuera de v1; Fase 6+).

### Centralización / trust post-deploy

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `Box*.owner` | Upgrade unilateral | Documentar; Ideal: Timelock/DAO (futuro) |
| `ProxyAdmin.owner` | Idem Transparent | `Ownable2Step` (rotar ownership; admin del proxy es immutable) |
| Admin = EOA que también usa el proxy | Transparent: admin no puede llamar lógica usuario | Usar `ProxyAdmin` dedicado (tests de clash) |
| Init olvidado | Proxy usable sin estado | Init en constructor del proxy (`data`) |

### SWC-126 / SWC-128 — `data` de upgrade pesado

Migraciones enormes en `upgradeToAndCall` pueden fallar por gas. Mitigación: migraciones acotadas / multi-step `reinitializer`.

### Layout storage

Romper offsets al upgradear corrompe estado. Mitigado con `__gap`, `forge inspect` (`doc/storage-layout.md`) y fuzz de persistencia.

---

## Checklist principios monorepo (+ módulo 11)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | `InvalidImplementation`, `AlreadyInitialized`, `UnauthorizedUpgrade`, `DelegateCallFailed` |
| Slots EIP-1967 | ✅ | impl + admin |
| `_disableInitializers` | ✅ | Box + UUPSCounter |
| `__gap` | ✅ | BoxV1 50 / BoxV2 49 |
| Transparent clash guard | ✅ | Admin path vs usuario |
| UUPS `onlyProxy` + UUID | ✅ | |
| NatSpec públicas/externas | ✅ | Core + Box |
| Fuzz ≥ 1000 runs | ✅ | `test/fuzz/StorageUpgrade.fuzz.t.sol` |
| Attack suite | ✅ | `test/attack/UnauthorizedUpgrade.t.sol` |
| Sin floating pragma | ✅ | `0.8.24` |
| Sin ETH `transfer`/`send` | ✅ | |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **ERC1967Proxy:** fallback/receive assembly `delegatecall`; slot impl; errores custom.
2. **TransparentProxy:** si `msg.sender == admin` (immutable) solo `upgradeToAndCall`; resto `UnauthorizedUpgrade`. Rotación de control vía `ProxyAdmin` Ownable2Step.
3. **UUPS:** `onlyProxy`; auth en `_authorizeUpgrade`; rechazo de impl no proxiable.
4. **Initializable:** doble init / init en impl → `AlreadyInitialized`.
5. **Box V1→V2:** slots 0/1 estables; `label` en slot 2; gap 50→49.

### Hardening Fase 5–6

| # | Cambio | Motivo |
|---|--------|--------|
| 1 | `test/UpgradeE2E.t.sol` | Ciclo completo UUPS + Transparent |
| 2 | `test/fuzz/StorageUpgrade.fuzz.t.sol` | Cero corrupción pre/post upgrade |
| 3 | `test/attack/UnauthorizedUpgrade.t.sol` | SWC-123 / auth bypass |
| 4 | `doc/SWC-AUDIT.md` | Matriz SWC-100–136 (estilo módulo 10) |
| 5 | Admin `immutable` + gas opts | Hot path sin SLOAD de admin / sin extcodesize |
| 6 | `script/Deploy.s.sol` + `doc/GAS.md` | Deploy reproducible + benchmarks |

### Observaciones no bloqueantes (v2 / Fase 6)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|-----------|-----------------|
| 1 | Sin Timelock en upgrades | Info | Gobernanza + delay |
| 2 | `implementation()` en ABI del proxy | Info | Posible clash si la lógica expone el mismo selector |
| 3 | Scripts de deploy / renuncia owner | Info | Fase 6 |
| 4 | Invariantes Foundry formales | Mejora | Handler store/upgrade |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `test/fuzz/StorageUpgrade.fuzz.t.sol` |
| SWC-103 | `forge build` pragma fijo |
| SWC-104 | `ERC1967Proxy` `DelegateCallFailed` / bubble |
| SWC-112 | E2E + UUPS `proxiableUUID` + NonUUPS reject |
| SWC-113 | `fail` / `failEmpty` en `ERC1967Proxy.t.sol` |
| SWC-114 | Documental |
| SWC-123 | unit + e2e + fuzz + attack |
| SWC-124 | `storage-layout.md` + slot asserts e2e/fuzz |
| Auth | `test/attack/UnauthorizedUpgrade.t.sol` |
| Layout | `BoxUpgrade.t.sol` + `UpgradeE2E` + fuzz |

---

## Resultado de ejecución

```text
forge test --summary
BoxUpgradeTest                   7 PASS
ERC1967ProxyTest                11 PASS
TransparentProxyTest            11 PASS
UUPSTest                        11 PASS
UpgradeE2ETest                   3 PASS
UnauthorizedUpgradeAttackTest    7 PASS
StorageUpgradeFuzzTest           4 PASS (1000 runs c/u)
ProxyGasTest                     6 PASS
Total: 60 PASS / 0 FAIL / 0 SKIP
```

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [EIP-1967](https://eips.ethereum.org/EIPS/eip-1967)
- [ERC-1822 (UUPS)](https://eips.ethereum.org/EIPS/eip-1822)
- Módulo 10: [`10-dao-governance/doc/SWC-AUDIT.md`](../../10-dao-governance/doc/SWC-AUDIT.md)
- Layout: [`storage-layout.md`](./storage-layout.md)
- Plan: [`planificacion.md`](./planificacion.md)
