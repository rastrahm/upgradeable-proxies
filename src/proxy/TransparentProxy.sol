// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "./ERC1967Proxy.sol";
import {ITransparentProxy} from "../interfaces/ITransparentProxy.sol";

/**
 * @title TransparentProxy
 * @notice Proxy ERC-1967 con separación admin / usuario (transparent proxy pattern).
 * @dev Admin en `immutable` (sin SLOAD en hot path) + slot EIP-1967 escrito una vez (compatibilidad).
 *      Cambio de control: transferir ownership del `ProxyAdmin`, no `changeAdmin` en el proxy.
 */
contract TransparentProxy is ERC1967Proxy {
    /**
     * @dev Slot ERC-1967 de admin (precomputado).
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @dev Admin inmutable para el routing (ahorra ~2100 gas vs SLOAD en frío / ~100 en caliente por call).
    address private immutable _adminAddress;

    /// @dev Selector de `upgradeToAndCall(address,bytes)`.
    bytes4 private constant UPGRADE_TO_AND_CALL_SELECTOR = ITransparentProxy.upgradeToAndCall.selector;

    /**
     * @notice Emitido al fijar el admin EIP-1967 (constructor).
     * @param previousAdmin Admin anterior.
     * @param newAdmin Nuevo admin.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @notice Despliega el proxy con lógica, admin y setup opcional.
     * @param implementation_ Contrato de lógica.
     * @param admin_ Dirección admin (debe ser `ProxyAdmin` dedicado).
     * @param data Calldata de inicialización vía `delegatecall`.
     */
    constructor(address implementation_, address admin_, bytes memory data) payable ERC1967Proxy(implementation_, data) {
        if (admin_ == address(0)) {
            revert UnauthorizedUpgrade();
        }
        _adminAddress = admin_;
        assembly {
            sstore(ADMIN_SLOT, admin_)
        }
        emit AdminChanged(address(0), admin_);
    }

    /**
     * @notice Lee el admin (immutable — misma dirección que el slot EIP-1967 post-deploy).
     * @return Dirección del admin actual.
     */
    function admin() external view returns (address) {
        return _adminAddress;
    }

    /**
     * @dev Si el caller es admin, solo `upgradeToAndCall`; si no, delegatecall transparente.
     */
    function _fallback() internal override {
        if (msg.sender == _adminAddress) {
            if (msg.sig == UPGRADE_TO_AND_CALL_SELECTOR) {
                _dispatchUpgradeToAndCall();
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
}
