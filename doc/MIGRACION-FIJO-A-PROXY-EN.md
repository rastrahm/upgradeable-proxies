# Outline — Migrating a fixed contract → upgradeable proxy

> 🌐 **English** · [Español](./MIGRACION-FIJO-A-PROXY-ES.md) · [Index](../README.md)

In real life this happens **more** often than ideal: many protocols launch immutable and later need bug fixes, fees, or compliance. The clean approach would have been a proxy from day 1; the real-world approach is usually a **migration**.

---

## 1. What migration does NOT do

```
Proxy ──delegatecall──► OldToken   ❌ does not inherit balances from old
```

The old contract's storage lives at the old contract's address. The new contract's storage lives in the **proxy**. State has to be **copied / credited**; you cannot "point" to the old one as if it were the same disk.

---

## 2. Typical architecture

```
                    ┌─────────────────┐
  users ───────────►│  OldToken       │  (fixed, already deployed)
                    │  pause/migrate  │
                    └────────┬────────┘
                             │ balanceOf / burn / lock
                             ▼
                    ┌─────────────────┐
                    │  Migrator       │  (optional; sometimes lives in NewToken)
                    └────────┬────────┘
                             │ mint / credit
                             ▼
                    ┌─────────────────┐
  new facade ──────►│  Proxy (EIP-1967)│  ← stable address FROM NOW ON
                    │       │         │
                    │  delegatecall   │
                    ▼                 │
                    NewToken V1       │
                    (upgradeable)     │
                    └─────────────────┘
```

- **OldToken:** is no longer the product; it only serves to exit / migrate.  
- **Proxy + NewToken:** is the new system (and already upgradeable).  
- The address that "counts" going forward is the **proxy's**, not the old one's.

---

## 3. User flow (the safest one)

```
1. Deploy NewToken V1 (with _disableInitializers)
2. Deploy ERC1967Proxy(NewToken, initialize(...))
3. OldToken.pause() or openMigrationOnly()
4. User:
      a) approves Migrator (if needed)
      b) calls migrate() / migrate(amount)
5. Migrator:
      - reads balance (or amount) on Old
      - burns or locks on Old (CEI)
      - credits/mints on New via proxy
6. Frontend / CEX / docs point to address(proxy)
7. Later on: upgradeToAndCall(NewToken V2) with no further mass migration
```

### Why "burn/lock + mint" and not just "copy"

If you only read the old contract and mint on the new one **without** invalidating the old one, the user ends up with a **double balance** (trivial attack). Migration must be **one-shot per account or per amount**.

---

## 4. Contract skeleton (educational)

### OldToken — controlled exit

```solidity
// Idea (this is not the module 11 production code)
contract OldToken {
    mapping(address => uint256) public balanceOf;
    bool public migrationOpen;
    address public migrator; // only this one can burn in migrate

    error NotMigrator();
    error MigrationClosed();

    function openMigration(address migrator_) external onlyOwner {
        migrator = migrator_;
        migrationOpen = true;
        // optional: pause regular transfers
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

### NewToken (behind the proxy) — entry

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

### Migrator — the one-shot bridge

```solidity
contract Migrator {
    OldToken public immutable oldToken;
    NewToken public immutable newToken; // PROXY address cast to NewToken
    mapping(address => bool) public migrated; // or tracking by amount

    error AlreadyMigrated();

    constructor(OldToken old_, NewToken newProxy_) {
        oldToken = old_;
        newToken = newProxy_;
    }

    function migrate() external {
        if (migrated[msg.sender]) revert AlreadyMigrated();
        uint256 amount = oldToken.balanceOf(msg.sender);
        require(amount > 0);

        migrated[msg.sender] = true;          // effects before interactions where applicable
        oldToken.burnFromForMigration(msg.sender, amount);
        newToken.mintFromMigration(msg.sender, amount);
    }
}
```

**Important:** `newToken` must be the **proxy's** address, not the implementation's.

---

## 5. Variants you will see in production

| Pattern | When | Note |
|--------|--------|------|
| **Pull** (`migrate()` per user) | Tokens / vaults with many holders | More gas per user; fairer |
| **Push / airdrop** (Merkle snapshot) | Many inactive holders | Off-chain snapshot; on-chain claim |
| **Vault wrapping** (old deposit → new shares) | TVL in a single contract | You migrate the vault, not each wallet |
| **Dual period** (old + new in parallel) | Smooth transition | Liquidity boundary / fragmented liquidity |
| **"Friendly" redeploy** (same brand, different address) | Governance / marketing | Socially it is still a migration |

---

## 6. Why it happens "more than ideal"

1. **Speed at launch:** proxy + gaps + init are intimidating at the start.  
2. **"We are never going to upgrade"** … until the first bug or feature.  
3. **Listings / integrations** already use the fixed address.  
4. **Audits:** sometimes only the minimal immutable part is audited and the upgrade is left "for later".  

Common outcome: **upgradeable V2 + migration event**, not a magic flip of the old contract.

---

## 7. Short checklist if you have to do it

- [ ] New behind a proxy (UUPS or Transparent) **before** migrating serious liquidity.  
- [ ] Old does not allow double claiming (burn/lock + `migrated` flag).  
- [ ] CEI / reentrancy in `migrate`.  
- [ ] Roles: only the Migrator can mint/burn for migration.  
- [ ] Migration deadline / closure.  
- [ ] Communicate the **new address** (proxy).  
- [ ] Tests: happy-path migrate, double migrate, amount 0, pause, unauthorized mint.  
- [ ] The **subsequent** upgrade plan no longer requires another mass migration.

---

## 8. Relationship with this module (11)

This repo teaches the **correct destination** (proxy + UUPS/Transparent + gaps).  
The old→proxy migration is the **painful bridge** when you did not start that way.

Mental flow:

```
Ideal:   Proxy(V1) → upgrade V2 → upgrade V3
Real:    Fixed old → Migrator → Proxy(V1) → upgrade V2 → …
```

The second line is more common than tutorials admit. The first one is what you should aim for **after** migrating once.
