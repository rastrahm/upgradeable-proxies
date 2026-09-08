// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ClashingLogic
 * @notice Impl con `upgradeToAndCall` para demostrar el camino transparente del usuario.
 * @dev Si el usuario llama `upgradeToAndCall` al proxy, debe hacer delegatecall aquí (marca `called`),
 *      no cambiar el slot EIP-1967 del proxy.
 */
contract ClashingLogic {
    /// @notice Flag seteado si el selector de upgrade llega por delegatecall.
    bool public called;

    /// @notice Valor de negocio en slot 0.
    uint256 public value;

    /**
     * @notice Simula una función de upgrade en la lógica (clash de selector).
     * @dev No escribe el slot EIP-1967; solo marca `called`.
     */
    function upgradeToAndCall(address, bytes calldata) external payable {
        called = true;
    }

    /**
     * @notice Escribe estado de negocio.
     * @param newValue Nuevo valor.
     */
    function setValue(uint256 newValue) external {
        value = newValue;
    }
}
