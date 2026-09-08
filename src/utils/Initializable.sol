// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ProxyErrors} from "../errors/ProxyErrors.sol";

/**
 * @title Initializable
 * @notice Patrón de inicialización para contratos detrás de proxy (sin constructor de negocio).
 * @dev Storage namespaced ERC-7201 para no colisionar con el layout de la lógica.
 *      Error de dominio: `AlreadyInitialized` (módulo 11).
 */
abstract contract Initializable is ProxyErrors {
    /**
     * @dev Storage del inicializable (ERC-7201).
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        uint64 _initialized;
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @notice Emitido al inicializar o reinicializar.
     * @param version Versión consumida.
     */
    event Initialized(uint64 version);

    /**
     * @dev Permite `initialize` una sola vez (versión 1).
     */
    modifier initializer() {
        InitializableStorage storage $ = _getInitializableStorage();
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert AlreadyInitialized();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev Reinicialización a `version` (p. ej. post-upgrade). Solo si `version` es mayor.
     * @param version Nueva versión de inicialización.
     */
    modifier reinitializer(uint64 version) {
        InitializableStorage storage $ = _getInitializableStorage();
        if ($._initializing || $._initialized >= version) {
            revert AlreadyInitialized();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Solo durante `initializer` / `reinitializer`.
     */
    modifier onlyInitializing() {
        if (!_isInitializing()) {
            revert AlreadyInitialized();
        }
        _;
    }

    /**
     * @dev Bloquea inicializadores en la implementación desplegada (llamar desde constructor).
     */
    function _disableInitializers() internal virtual {
        InitializableStorage storage $ = _getInitializableStorage();
        if ($._initializing) {
            revert AlreadyInitialized();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Versión más alta ya inicializada.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev `true` si hay un initializer en curso.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}
