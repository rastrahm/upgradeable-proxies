// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ITransparentProxy
 * @notice API administrativa del Transparent Proxy (la llama el `ProxyAdmin`, no el ABI del proxy).
 * @dev El proxy no declara estas funciones en su ABI: las despacha en el fallback si `msg.sender` es admin.
 */
interface ITransparentProxy {
    /**
     * @notice Actualiza la implementación y opcionalmente ejecuta `data`.
     * @param newImplementation Nueva lógica.
     * @param data Calldata de migración/init.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;

    /**
     * @notice Cambia el admin EIP-1967 del proxy.
     * @param newAdmin Nuevo admin (típicamente otro `ProxyAdmin`).
     */
    function changeAdmin(address newAdmin) external;
}
