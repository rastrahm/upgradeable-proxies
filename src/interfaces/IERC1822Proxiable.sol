// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IERC1822Proxiable
 * @notice UUID proxiable (ERC-1822) para validar implementaciones UUPS.
 */
interface IERC1822Proxiable {
    /**
     * @notice Slot que la impl asume para la dirección de implementación.
     * @return UUID (slot EIP-1967 de implementation).
     */
    function proxiableUUID() external view returns (bytes32);
}
