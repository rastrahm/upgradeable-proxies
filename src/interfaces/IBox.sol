// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IBox
 * @notice API de negocio demo upgradeable (Box V1/V2).
 */
interface IBox {
    /**
     * @notice Inicializa owner y valor (solo una vez vía proxy).
     * @param owner_ Dueño autorizado a upgradear.
     * @param initialValue Valor inicial.
     */
    function initialize(address owner_, uint256 initialValue) external;

    /**
     * @notice Escribe el valor almacenado.
     * @param newValue Nuevo valor.
     */
    function store(uint256 newValue) external;

    /**
     * @notice Lee el valor almacenado.
     * @return Valor actual en storage del proxy.
     */
    function retrieve() external view returns (uint256);

    /**
     * @notice Identificador de versión de lógica.
     * @return Versión como string.
     */
    function version() external pure returns (string memory);
}
