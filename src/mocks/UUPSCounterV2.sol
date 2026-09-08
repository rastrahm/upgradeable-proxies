// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "../utils/Initializable.sol";
import {UUPSUpgradeable} from "../uups/UUPSUpgradeable.sol";

/**
 * @title UUPSCounterV2
 * @notice Lógica UUPS de prueba (V2): mismo layout owner/value + `reinitializer(2)`.
 */
contract UUPSCounterV2 is Initializable, UUPSUpgradeable {
    /// @notice Dueño autorizado a upgradear.
    address public owner;

    /// @notice Valor de negocio (debe persistir tras upgrade).
    uint256 public value;

    /// @notice Etiqueta añadida en V2 (slot nuevo tras owner/value).
    string public label;

    /**
     * @notice Deshabilita initializers en la impl desplegada.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Init V1-compatible (por si se despliega fresco); en upgrade usar `initializeV2`.
     * @param owner_ Dueño.
     * @param initialValue Valor inicial.
     */
    function initialize(address owner_, uint256 initialValue) external initializer {
        if (owner_ == address(0)) {
            revert UnauthorizedUpgrade();
        }
        owner = owner_;
        value = initialValue;
    }

    /**
     * @notice Migración post-upgrade a V2.
     * @param label_ Etiqueta nueva.
     */
    function initializeV2(string calldata label_) external reinitializer(2) {
        label = label_;
    }

    /**
     * @notice Escribe `newValue`.
     * @param newValue Nuevo valor.
     */
    function setValue(uint256 newValue) external {
        value = newValue;
    }

    /**
     * @notice Versión de lógica.
     * @return Literal `"2"`.
     */
    function version() external pure returns (string memory) {
        return "2";
    }

    /**
     * @inheritdoc UUPSUpgradeable
     */
    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != owner) {
            revert UnauthorizedUpgrade();
        }
    }
}
