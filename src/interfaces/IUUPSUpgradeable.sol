// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IUUPSUpgradeable
 * @notice API de upgrade UUPS expuesta vía proxy (`delegatecall`).
 */
interface IUUPSUpgradeable {
    /**
     * @notice Actualiza la implementación del proxy y opcionalmente ejecuta `data`.
     * @param newImplementation Nueva lógica UUPS-compatible.
     * @param data Calldata de migración; vacío si no hay llamada.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
