// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ITransparentProxy} from "../interfaces/ITransparentProxy.sol";
import {ProxyErrors} from "../errors/ProxyErrors.sol";

/**
 * @title ProxyAdmin
 * @notice Dueño del Transparent Proxy: único caller privilegiado para upgrades.
 * @dev Ownership con `Ownable2Step`. Rotar control = `transferOwnership` + `acceptOwnership`.
 */
contract ProxyAdmin is Ownable2Step, ProxyErrors {
    /**
     * @notice Versión de la interfaz de upgrade (alineada a OZ 5.x: solo `upgradeAndCall`).
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @notice Fija el owner inicial (quien autoriza upgrades).
     * @param initialOwner Owner del admin.
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) {
            revert UnauthorizedUpgrade();
        }
    }

    /**
     * @notice Actualiza la implementación del `proxy` y ejecuta `data` si no está vacío.
     * @param proxy Transparent proxy gestionado por este admin.
     * @param implementation Nueva lógica.
     * @param data Calldata de migración; `""` si no hay llamada post-upgrade.
     */
    function upgradeAndCall(ITransparentProxy proxy, address implementation, bytes calldata data)
        external
        payable
        onlyOwner
    {
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
    }
}
