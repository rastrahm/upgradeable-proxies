// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "../utils/Initializable.sol";
import {UUPSUpgradeable} from "../uups/UUPSUpgradeable.sol";
import {IBox} from "../interfaces/IBox.sol";

/**
 * @title BoxV1
 * @notice Implementación de negocio V1 con gap de storage para upgrades futuros.
 * @dev Layout: `owner` (slot 0), `value` (slot 1), `__gap` (50 slots). Initializable es ERC-7201.
 */
contract BoxV1 is Initializable, UUPSUpgradeable, IBox {
    /// @notice Dueño autorizado a ejecutar upgrades UUPS.
    address public owner;

    /// @notice Valor de negocio.
    uint256 public value;

    /// @dev Reserva 50 slots para variables futuras sin colisión.
    uint256[50] private __gap;

    /**
     * @notice Bloquea initializers en la implementación desplegada.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @inheritdoc IBox
     */
    function initialize(address owner_, uint256 initialValue) external override initializer {
        if (owner_ == address(0)) {
            revert UnauthorizedUpgrade();
        }
        owner = owner_;
        value = initialValue;
    }

    /**
     * @inheritdoc IBox
     */
    function store(uint256 newValue) external override {
        value = newValue;
    }

    /**
     * @inheritdoc IBox
     */
    function retrieve() external view override returns (uint256) {
        return value;
    }

    /**
     * @inheritdoc IBox
     */
    function version() external pure override returns (string memory) {
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
