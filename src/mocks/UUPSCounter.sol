// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "../utils/Initializable.sol";
import {UUPSUpgradeable} from "../uups/UUPSUpgradeable.sol";

/**
 * @title UUPSCounter
 * @notice Lógica UUPS de prueba (V1): owner + value, inicializable vía proxy.
 */
contract UUPSCounter is Initializable, UUPSUpgradeable {
    /// @notice Dueño autorizado a upgradear.
    address public owner;

    /// @notice Valor de negocio (storage del proxy).
    uint256 public value;

    /**
     * @notice Deshabilita initializers en la impl desplegada.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inicializa owner y valor inicial (solo vía proxy, una vez).
     * @param owner_ Dueño del upgrade.
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
     * @notice Escribe `newValue`.
     * @param newValue Nuevo valor.
     */
    function setValue(uint256 newValue) external {
        value = newValue;
    }

    /**
     * @notice Versión de lógica.
     * @return Literal `"1"`.
     */
    function version() external pure returns (string memory) {
        return "1";
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
