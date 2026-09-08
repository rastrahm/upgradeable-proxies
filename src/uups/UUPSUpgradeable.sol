// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC1822Proxiable} from "../interfaces/IERC1822Proxiable.sol";
import {IUUPSUpgradeable} from "../interfaces/IUUPSUpgradeable.sol";
import {ProxyErrors} from "../errors/ProxyErrors.sol";

/**
 * @title UUPSUpgradeable
 * @notice Mecánica de upgrade UUPS: la autorización vive en la implementación.
 * @dev `upgradeToAndCall` usa `calldata` (sin copia a memory). Slot EIP-1967 precomputado.
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable, IUUPSUpgradeable, ProxyErrors {
    /// @dev Dirección de este contrato de lógica (no la del proxy).
    address private immutable __self = address(this);

    /**
     * @dev Slot EIP-1967 de implementación (precomputado).
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

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
    function upgradeToAndCall(address newImplementation, bytes calldata data) public payable virtual onlyProxy {
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
    function _upgradeToAndCallUUPS(address newImplementation, bytes calldata data) private {
        assembly {
            if iszero(extcodesize(newImplementation)) {
                mstore(0x00, shl(224, 0x68155f9a))
                revert(0x00, 0x04)
            }
        }

        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != IMPLEMENTATION_SLOT) {
                revert InvalidImplementation();
            }
            _setImplementation(newImplementation);
            if (data.length > 0) {
                _delegateCallCalldata(newImplementation, data);
            } else if (msg.value > 0) {
                revert InvalidImplementation();
            }
        } catch {
            revert InvalidImplementation();
        }
    }

    /**
     * @dev `delegatecall` desde `calldata` (evita copiar `data` a memory).
     */
    function _delegateCallCalldata(address implementation_, bytes calldata data) private {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, data.offset, data.length)
            let success := delegatecall(gas(), implementation_, ptr, data.length, 0, 0)
            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                if returndatasize() {
                    revert(0, returndatasize())
                }
                mstore(0x00, shl(224, 0x18cecad5))
                revert(0x00, 0x04)
            }
        }
    }

    /**
     * @dev Lee el slot EIP-1967 de implementación.
     */
    function _getImplementation() private view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev Escribe el slot EIP-1967 y emite `Upgraded`.
     */
    function _setImplementation(address newImplementation) private {
        assembly {
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }
        emit Upgraded(newImplementation);
    }
}
