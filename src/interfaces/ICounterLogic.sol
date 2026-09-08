// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ICounterLogic
 * @notice API mínima de lógica de prueba para el proxy ERC-1967 (Fase 1).
 */
interface ICounterLogic {
    /// @notice Valor almacenado (en el storage del proxy vía delegatecall).
    function value() external view returns (uint256);

    /// @notice Escribe `newValue` en storage.
    /// @param newValue Nuevo valor.
    function setValue(uint256 newValue) external;

    /// @notice Incrementa el valor en 1.
    function increment() external;

    /// @notice Recibe ETH y acumula `msg.value` en `value`.
    function deposit() external payable;

    /// @notice Siempre revierte (para probar DelegateCallFailed / bubbling).
    function fail() external pure;

    /// @notice Revierte sin returndata (assembly `revert(0,0)`).
    function failEmpty() external pure;
}
