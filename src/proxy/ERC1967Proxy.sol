// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ProxyErrors} from "../errors/ProxyErrors.sol";

/**
 * @title ERC1967Proxy
 * @notice Proxy mínimo EIP-1967: enruta llamadas con `delegatecall` a la implementación.
 * @dev Slot: `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)`.
 *      Preserva `msg.sender` y `msg.value` vía `delegatecall` en fallback/receive (assembly).
 */
contract ERC1967Proxy is ProxyErrors {
    /**
     * @dev Slot ERC-1967 de implementación.
     *      `keccak256("eip1967.proxy.implementation") - 1`
     */
    bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    /**
     * @notice Emitido al fijar o cambiar la implementación.
     * @param implementation Nueva dirección de lógica.
     */
    event Upgraded(address indexed implementation);

    /**
     * @notice Despliega el proxy apuntando a `implementation_` y opcionalmente inicializa.
     * @param implementation_ Contrato de lógica (debe tener código).
     * @param data Calldata para `delegatecall` de setup; vacío = sin llamada extra.
     */
    constructor(address implementation_, bytes memory data) payable {
        _setImplementation(implementation_);
        if (data.length > 0) {
            _delegateCall(implementation_, data);
        } else if (msg.value > 0) {
            revert InvalidImplementation();
        }
    }

    /**
     * @notice Enruta cualquier llamada (con o sin valor) a la implementación actual.
     */
    fallback() external payable {
        _fallback();
    }

    /**
     * @notice Recibe ETH puro y lo delega a la implementación.
     */
    receive() external payable {
        _fallback();
    }

    /**
     * @notice Lee la implementación desde el slot EIP-1967 (útil en tests / ops).
     * @return impl Dirección actual de la lógica.
     */
    function implementation() external view returns (address impl) {
        impl = _implementation();
    }

    /**
     * @dev Lee el slot EIP-1967 de implementación.
     */
    function _implementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Escribe el slot EIP-1967 tras validar código en `newImplementation`.
     */
    function _setImplementation(address newImplementation) internal {
        if (newImplementation == address(0) || newImplementation.code.length == 0) {
            revert InvalidImplementation();
        }
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Obtiene la impl y ejecuta `delegatecall` con el calldata actual.
     */
    function _fallback() internal {
        address impl = _implementation();
        if (impl == address(0) || impl.code.length == 0) {
            revert InvalidImplementation();
        }
        _delegate(impl);
    }

    /**
     * @dev `delegatecall` del calldata completo; no retorna al Solidity caller (return/revert en assembly).
     */
    function _delegate(address implementation_) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                if returndatasize() {
                    revert(0, returndatasize())
                }
                // Selector de DelegateCallFailed() = 0x18cecad5
                mstore(0x00, shl(224, 0x18cecad5))
                revert(0x00, 0x04)
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev `delegatecall` con `data` arbitrario (constructor / setup).
     */
    function _delegateCall(address implementation_, bytes memory data) internal {
        (bool success, bytes memory returndata) = implementation_.delegatecall(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert DelegateCallFailed();
        }
    }
}
