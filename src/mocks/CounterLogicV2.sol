// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ICounterLogic} from "../interfaces/ICounterLogic.sol";

/**
 * @title CounterLogicV2
 * @notice Segunda implementación de prueba para upgrades Transparent (Fase 2).
 * @dev Mismo layout de `value` (slot 0); añade `version` solo como función pura.
 */
contract CounterLogicV2 is ICounterLogic {
    /// @inheritdoc ICounterLogic
    uint256 public override value;

    /// @inheritdoc ICounterLogic
    function setValue(uint256 newValue) external override {
        value = newValue;
    }

    /// @inheritdoc ICounterLogic
    function increment() external override {
        unchecked {
            value += 1;
        }
    }

    /// @inheritdoc ICounterLogic
    function deposit() external payable override {
        value += msg.value;
    }

    /// @inheritdoc ICounterLogic
    function fail() external pure override {
        revert("CounterLogicV2: fail");
    }

    /// @inheritdoc ICounterLogic
    function failEmpty() external pure override {
        assembly {
            revert(0, 0)
        }
    }

    /**
     * @notice Identificador de versión de lógica.
     * @return Literal `"2"`.
     */
    function version() external pure returns (string memory) {
        return "2";
    }
}
