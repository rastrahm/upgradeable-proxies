// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC1822Proxiable} from "../interfaces/IERC1822Proxiable.sol";
import {IUUPSUpgradeable} from "../interfaces/IUUPSUpgradeable.sol";
import {ProxyErrors} from "../errors/ProxyErrors.sol";

/**
 * @title UUPSUpgradeable
 * @notice Mecánica de upgrade UUPS: la autorización vive en la implementación.
 * @dev Debe usarse detrás de un `ERC1967Proxy`. `upgradeToAndCall` solo vía `delegatecall` (`onlyProxy`).
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable, IUUPSUpgradeable, ProxyErrors {
    /// @dev Dirección de este contrato de lógica (no la del proxy).
    address private immutable __self = address(this);

    /**
     * @dev Slot EIP-1967 de implementación.
     */
    bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    /**
     * @notice Versión de interfaz de upgrade (solo `upgradeToAndCall`).
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @notice Emitido al cambiar la implementación (contexto = dirección del proxy).
     * @param implementation Nueva lógica.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Exige ejecución vía proxy (`delegatecall` + slot impl == `__self`).
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Exige NO estar en `delegatecall` (p. ej. `proxiableUUID`).
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    /**
     * @inheritdoc IERC1822Proxiable
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }

    /**
     * @inheritdoc IUUPSUpgradeable
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Hook de autorización (p. ej. `onlyOwner`). Debe revertir con `UnauthorizedUpgrade`.
     * @param newImplementation Destino del upgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Valida contexto UUPS (llamada a través del proxy activo).
     */
    function _checkProxy() internal view virtual {
        if (address(this) == __self || _getImplementation() != __self) {
            revert UnauthorizedUpgrade();
        }
    }

    /**
     * @dev Valida que no se llame vía `delegatecall`.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            revert UnauthorizedUpgrade();
        }
    }

    /**
     * @dev Upgrade con chequeo ERC-1822 + escritura del slot EIP-1967.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        if (newImplementation == address(0) || newImplementation.code.length == 0) {
            revert InvalidImplementation();
        }

        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != IMPLEMENTATION_SLOT) {
                revert InvalidImplementation();
            }
            _setImplementation(newImplementation);
            if (data.length > 0) {
                (bool success, bytes memory returndata) = newImplementation.delegatecall(data);
                if (!success) {
                    if (returndata.length > 0) {
                        assembly {
                            revert(add(returndata, 0x20), mload(returndata))
                        }
                    }
                    revert DelegateCallFailed();
                }
            } else if (msg.value > 0) {
                revert InvalidImplementation();
            }
        } catch {
            revert InvalidImplementation();
        }
    }

    /**
     * @dev Lee el slot EIP-1967 de implementación (storage del proxy en contexto delegatecall).
     */
    function _getImplementation() private view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Escribe el slot EIP-1967 y emite `Upgraded`.
     */
    function _setImplementation(address newImplementation) private {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
        emit Upgraded(newImplementation);
    }
}
