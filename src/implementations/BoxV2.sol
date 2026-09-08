// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "../utils/Initializable.sol";
import {UUPSUpgradeable} from "../uups/UUPSUpgradeable.sol";
import {IBox} from "../interfaces/IBox.sol";

/**
 * @title BoxV2
 * @notice Implementación V2: añade `label` al final del layout V1 (reduce `__gap` de 50 → 49).
 * @dev `owner` y `value` conservan offsets; `label` ocupa el primer slot que antes era del gap.
 */
contract BoxV2 is Initializable, UUPSUpgradeable, IBox {
    /// @notice Dueño autorizado a ejecutar upgrades UUPS.
    address public owner;

    /// @notice Valor de negocio (persiste tras upgrade desde V1).
    uint256 public value;

    /// @notice Etiqueta nueva en V2 (primer slot liberado del gap).
    string public label;

    /// @dev Gap reducido en 1 respecto a V1 (50 → 49) al añadir `label`.
    uint256[49] private __gap;

    /**
     * @notice Bloquea initializers en la implementación desplegada.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @inheritdoc IBox
     * @dev Útil si se despliega V2 en fresco; en upgrade desde V1 usar `initializeV2`.
     */
    function initialize(address owner_, uint256 initialValue) external override initializer {
        if (owner_ == address(0)) {
            revert UnauthorizedUpgrade();
        }
        owner = owner_;
        value = initialValue;
    }

    /**
     * @notice Migración post-upgrade desde BoxV1.
     * @param label_ Etiqueta inicial de V2.
     */
    function initializeV2(string calldata label_) external reinitializer(2) {
        label = label_;
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
     * @notice Actualiza la etiqueta.
     * @param label_ Nueva etiqueta.
     */
    function setLabel(string calldata label_) external {
        label = label_;
    }

    /**
     * @inheritdoc IBox
     */
    function version() external pure override returns (string memory) {
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
