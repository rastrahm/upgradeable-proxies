// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "./ERC1967Proxy.sol";
import {ITransparentProxy} from "../interfaces/ITransparentProxy.sol";

/**
 * @title TransparentProxy
 * @notice Proxy ERC-1967 con separación admin / usuario (transparent proxy pattern).
 * @dev Si `msg.sender == admin`: solo `upgradeToAndCall` / `changeAdmin` (dispatch en fallback).
 *      Si no: `delegatecall` a la implementación (incluso si el selector coincide con admin).
 */
contract TransparentProxy is ERC1967Proxy {
    /**
     * @dev Slot ERC-1967 de admin: `keccak256("eip1967.proxy.admin") - 1`.
     */
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    /// @dev Selector de `upgradeToAndCall(address,bytes)`.
    bytes4 private constant UPGRADE_TO_AND_CALL_SELECTOR = ITransparentProxy.upgradeToAndCall.selector;

    /// @dev Selector de `changeAdmin(address)`.
    bytes4 private constant CHANGE_ADMIN_SELECTOR = ITransparentProxy.changeAdmin.selector;

    /**
     * @notice Emitido al cambiar el admin EIP-1967.
     * @param previousAdmin Admin anterior.
     * @param newAdmin Nuevo admin.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @notice Despliega el proxy con lógica, admin y setup opcional.
     * @param implementation_ Contrato de lógica.
     * @param admin_ Dirección admin (debe ser `ProxyAdmin` u otro contrato dedicado).
     * @param data Calldata de inicialización vía `delegatecall`.
     */
    constructor(address implementation_, address admin_, bytes memory data) payable ERC1967Proxy(implementation_, data) {
        _setAdmin(admin_);
    }

    /**
     * @notice Lee el admin desde el slot EIP-1967.
     * @return Dirección del admin actual.
     */
    function admin() external view returns (address) {
        return _admin();
    }

    /**
     * @dev Si el caller es admin, despacha upgrade/changeAdmin; si no, delegatecall transparente.
     */
    function _fallback() internal override {
        if (msg.sender == _admin()) {
            bytes4 sig = msg.sig;
            if (sig == UPGRADE_TO_AND_CALL_SELECTOR) {
                _dispatchUpgradeToAndCall();
            } else if (sig == CHANGE_ADMIN_SELECTOR) {
                _dispatchChangeAdmin();
            } else {
                revert UnauthorizedUpgrade();
            }
        } else {
            super._fallback();
        }
    }

    /**
     * @dev Decodifica calldata de `upgradeToAndCall` y actualiza la impl.
     */
    function _dispatchUpgradeToAndCall() private {
        (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
        _upgradeToAndCall(newImplementation, data);
    }

    /**
     * @dev Decodifica calldata de `changeAdmin` y escribe el slot admin.
     */
    function _dispatchChangeAdmin() private {
        address newAdmin = abi.decode(msg.data[4:], (address));
        _setAdmin(newAdmin);
    }

    /**
     * @dev Lee el slot admin EIP-1967.
     */
    function _admin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev Escribe el slot admin EIP-1967.
     */
    function _setAdmin(address newAdmin) internal {
        if (newAdmin == address(0)) {
            revert UnauthorizedUpgrade();
        }
        address previous = _admin();
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
        emit AdminChanged(previous, newAdmin);
    }
}
