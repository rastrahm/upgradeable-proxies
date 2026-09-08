// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ICounterLogic} from "../interfaces/ICounterLogic.sol";

/**
 * @title CounterLogic
 * @notice Implementación de prueba: el estado debe vivir en el proxy, no aquí.
 * @dev No usar en producción; solo para tests de delegatecall / storage.
 */
contract CounterLogic is ICounterLogic {
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
        revert("CounterLogic: fail");
    }

    /// @inheritdoc ICounterLogic
    function failEmpty() external pure override {
        assembly {
            revert(0, 0)
        }
    }
}
