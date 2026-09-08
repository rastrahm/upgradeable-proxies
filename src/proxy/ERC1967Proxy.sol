// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ProxyErrors} from "../errors/ProxyErrors.sol";

/**
 * @title ERC1967Proxy
 * @notice Proxy mínimo EIP-1967: enruta llamadas con `delegatecall` a la implementación.
 * @dev Hot path: un `sload` del slot + `delegatecall` (sin `extcodesize` por llamada).
 *      Validación de código solo al setear la implementación.
 */
contract ERC1967Proxy is ProxyErrors {
    /**
     * @dev Slot ERC-1967 de implementación (constante precomputada EIP-1967).
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

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
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev Escribe el slot EIP-1967 tras validar `extcodesize` (cubre `address(0)`).
     */
    function _setImplementation(address newImplementation) internal {
        assembly {
            if iszero(extcodesize(newImplementation)) {
                mstore(0x00, shl(224, 0x68155f9a))
                revert(0x00, 0x04)
            }
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Hot path: sload + delegatecall (sin extcodesize).
     */
    function _fallback() internal virtual {
        address impl;
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
            if iszero(impl) {
                mstore(0x00, shl(224, 0x68155f9a))
                revert(0x00, 0x04)
            }
        }
        _delegate(impl);
    }

    /**
     * @dev Cambia la implementación y opcionalmente ejecuta `data` vía `delegatecall`.
     * @param newImplementation Nueva lógica (con código).
     * @param data Calldata de setup/migración; vacío = sin llamada.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        if (data.length > 0) {
            _delegateCall(newImplementation, data);
        } else if (msg.value > 0) {
            revert InvalidImplementation();
        }
    }

    /**
     * @dev `delegatecall` del calldata completo; return/revert en assembly.
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
                mstore(0x00, shl(224, 0x18cecad5))
                revert(0x00, 0x04)
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev `delegatecall` con `data` en memory (constructor / upgrade); no hace `return` al caller.
     */
    function _delegateCall(address implementation_, bytes memory data) internal {
        assembly {
            let success := delegatecall(gas(), implementation_, add(data, 0x20), mload(data), 0, 0)
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
}
