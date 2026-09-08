// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ITransparentProxy
 * @notice API administrativa del Transparent Proxy (la llama el `ProxyAdmin`).
 * @dev El proxy no declara esta función en su ABI: la despacha en el fallback si `msg.sender` es admin.
 *      El admin es immutable: para rotar control, transferir ownership del `ProxyAdmin`.
 */
interface ITransparentProxy {
    /**
     * @notice Actualiza la implementación y opcionalmente ejecuta `data`.
     * @param newImplementation Nueva lógica.
     * @param data Calldata de migración/init.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}
