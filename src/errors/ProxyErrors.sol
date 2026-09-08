// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ProxyErrors
 * @notice Errores custom del módulo de proxies upgradeables.
 */
interface ProxyErrors {
    /// @notice Implementación nula, sin código o inválida para EIP-1967.
    error InvalidImplementation();

    /// @notice El contrato ya fue inicializado.
    error AlreadyInitialized();

    /// @notice Caller no autorizado para upgrade / admin.
    error UnauthorizedUpgrade();

    /// @notice El `delegatecall` al implementation falló sin returndata.
    error DelegateCallFailed();
}
