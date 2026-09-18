# Bosquejo — Migrar contrato fijo → proxy upgradeable

En la vida real pasa **más** de lo ideal: muchos protocolos arrancan inmutables y después necesitan bugs fixes, fees o compliance. La forma limpia habría sido proxy desde el día 1; la forma real suele ser **migración**.

---

## 1. Qué NO hace la migración

```
Proxy ──delegatecall──► OldToken   ❌ no hereda balances del old
```

El storage del old vive en la address del old. El storage del nuevo vive en el **proxy**. Hay que **copiar / acreditar** estado, no “apuntar” al viejo como si fuera el mismo disco.

---

## 2. Arquitectura típica

```
                    ┌─────────────────┐
  usuarios ────────►│  OldToken       │  (fijo, ya desplegado)
                    │  pause/migrate  │
                    └────────┬────────┘
                             │ balanceOf / burn / lock
                             ▼
                    ┌─────────────────┐
                    │  Migrator       │  (opcional; a veces va en NewToken)
                    └────────┬────────┘
                             │ mint / credit
                             ▼
                    ┌─────────────────┐
  nueva cara ──────►│  Proxy (EIP-1967)│  ← address estable DE AHORA EN MÁS
                    │       │         │
                    │  delegatecall   │
                    ▼                 │
                    NewToken V1       │
                    (upgradeable)     │
                    └─────────────────┘
```

- **OldToken:** deja de ser el producto; solo sirve para salir / migrar.  
- **Proxy + NewToken:** es el sistema nuevo (y ya upgradeable).  
- La address que “cuenta” a futuro es la del **proxy**, no la del old.

---

## 3. Flujo de usuario (el más seguro)

```
1. Deploy NewToken V1 (con _disableInitializers)
2. Deploy ERC1967Proxy(NewToken, initialize(...))
3. OldToken.pause() o openMigrationOnly()
4. Usuario:
      a) aprueba Migrator (si hace falta)
      b) llama migrate() / migrate(amount)
5. Migrator:
      - lee balance (o amount) en Old
      - quema o bloquea en Old (CEI)
      - acredita/mint en New vía proxy
6. Frontend / CEX / docs apuntan a address(proxy)
7. Más adelante: upgradeToAndCall(NewToken V2) sin otra migración masiva
```

### Por qué “quema/bloquea + mint” y no solo “copiar”

Si solo leés el old y mintás en el nuevo **sin** invalidar el viejo, el usuario se queda con **doble balance** (ataque trivial). La migración tiene que ser **one-shot por cuenta o por amount**.

---

## 4. Esqueleto de contratos (didáctico)

### OldToken — salida controlada

```solidity
// Idea (no es el código de producción del módulo 11)
contract OldToken {
    mapping(address => uint256) public balanceOf;
    bool public migrationOpen;
    address public migrator; // solo este puede quemar en migrate

    error NotMigrator();
    error MigrationClosed();

    function openMigration(address migrator_) external onlyOwner {
        migrator = migrator_;
        migrationOpen = true;
        // opcional: pause transfers normales
    }

    function burnFromForMigration(address from, uint256 amount) external {
        if (msg.sender != migrator) revert NotMigrator();
        if (!migrationOpen) revert MigrationClosed();
        uint256 bal = balanceOf[from];
        require(amount <= bal);
        unchecked { balanceOf[from] = bal - amount; }
        // totalSupply -= amount;
    }
}
```

### NewToken (detrás del proxy) — entrada

```solidity
contract NewToken is Initializable, UUPSUpgradeable {
    mapping(address => uint256) public balanceOf;
    address public migrator;

    function initialize(address owner_, address migrator_) external initializer {
        // owner, migrator, ...
        migrator = migrator_;
    }

    function mintFromMigration(address to, uint256 amount) external {
        require(msg.sender == migrator);
        balanceOf[to] += amount;
        // totalSupply += amount;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
```

### Migrator — el puente one-shot

```solidity
contract Migrator {
    OldToken public immutable oldToken;
    NewToken public immutable newToken; // address del PROXY casteada a NewToken
    mapping(address => bool) public migrated; // o tracking por amount

    error AlreadyMigrated();

    constructor(OldToken old_, NewToken newProxy_) {
        oldToken = old_;
        newToken = newProxy_;
    }

    function migrate() external {
        if (migrated[msg.sender]) revert AlreadyMigrated();
        uint256 amount = oldToken.balanceOf(msg.sender);
        require(amount > 0);

        migrated[msg.sender] = true;          // effects antes de interactions si aplica
        oldToken.burnFromForMigration(msg.sender, amount);
        newToken.mintFromMigration(msg.sender, amount);
    }
}
```

**Importante:** `newToken` debe ser la address del **proxy**, no la de la implementación.

---

## 5. Variantes que verás en producción

| Patrón | Cuándo | Nota |
|--------|--------|------|
| **Pull** (`migrate()` por usuario) | Tokens / vaults con muchos holders | Más gas por usuario; más justo |
| **Push / airdrop** (Merkle snapshot) | Muchos holders inactivos | Snapshot off-chain; claim on-chain |
| **Vault wrapping** (old deposit → shares new) | TVL en un solo contrato | Migrás el vault, no cada wallet |
| **Dual period** (old + new en paralelo) | Transición suave | Frontera de liquidez / liquidez fragmentada |
| **Redeploy “amigo”** (misma marca, otra address) | Gobernanza / marketing | Socialmente es migración igual |

---

## 6. Por qué ocurre “más de lo ideal”

1. **Velocidad al lanzar:** proxy + gaps + init asustan al inicio.  
2. **“No vamos a upgradear”** … hasta el primer bug o feature.  
3. **Listings / integraciones** ya usan la address fija.  
4. **Auditorías:** a veces se audita lo mínimo inmutable y el upgrade se deja “para después”.  

Resultado frecuente: **V2 upgradeable + evento de migración**, no un flip mágico del contrato viejo.

---

## 7. Checklist corto si te toca hacerlo

- [ ] New detrás de proxy (UUPS o Transparent) **antes** de migrar liquidez seria.  
- [ ] Old no permite doble cobro (burn/lock + flag `migrated`).  
- [ ] CEI / reentrancy en `migrate`.  
- [ ] Roles: solo Migrator mint/burn de migración.  
- [ ] Deadline / cierre de migración.  
- [ ] Comunicar la **nueva address** (proxy).  
- [ ] Tests: migrate feliz, doble migrate, amount 0, pause, unauthorized mint.  
- [ ] Plan de upgrade **posterior** ya no requiere otra migración masiva.

---

## 8. Relación con este módulo (11)

Este repo enseña el **destino correcto** (proxy + UUPS/Transparent + gaps).  
La migración old→proxy es el **puente doloroso** cuando no empezaste así.

Flujo mental:

```
Ideal:   Proxy(V1) → upgrade V2 → upgrade V3
Real:    Old fijo → Migrator → Proxy(V1) → upgrade V2 → …
```

La segunda línea es más común de lo que dicen los tutorials. La primera es a lo que deberías apuntar **después** de migrar una vez.
