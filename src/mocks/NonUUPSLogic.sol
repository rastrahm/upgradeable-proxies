// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title NonUUPSLogic
 * @notice Contrato con código pero sin `proxiableUUID` (upgrade UUPS inválido).
 */
contract NonUUPSLogic {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}
