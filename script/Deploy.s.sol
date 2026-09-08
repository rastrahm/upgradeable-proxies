// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";
import {TransparentProxy} from "../src/proxy/TransparentProxy.sol";
import {ProxyAdmin} from "../src/proxy/ProxyAdmin.sol";
import {BoxV1} from "../src/implementations/BoxV1.sol";
import {IBox} from "../src/interfaces/IBox.sol";
import {CounterLogic} from "../src/mocks/CounterLogic.sol";

/**
 * @title Deploy
 * @notice Despliega stacks demo UUPS (Box) y Transparent (Counter + ProxyAdmin).
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 */
contract Deploy is Script {
    /**
     * @notice Despliega ambos patrones y deja direcciones en logs.
     */
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);
        uint256 initialValue = vm.envOr("INITIAL_VALUE", uint256(0));

        vm.startBroadcast(pk);

        // --- UUPS: BoxV1 detrás de ERC1967Proxy ---
        BoxV1 boxImpl = new BoxV1();
        bytes memory boxInit = abi.encodeCall(IBox.initialize, (deployer, initialValue));
        ERC1967Proxy uupsProxy = new ERC1967Proxy(address(boxImpl), boxInit);

        // --- Transparent: CounterLogic + ProxyAdmin ---
        CounterLogic counterImpl = new CounterLogic();
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployer);
        TransparentProxy transparentProxy = new TransparentProxy(address(counterImpl), address(proxyAdmin), "");

        vm.stopBroadcast();

        console2.log("=== Upgradeable Proxies Deploy ===");
        console2.log("Deployer", deployer);
        console2.log("BoxV1 impl", address(boxImpl));
        console2.log("UUPS proxy (Box)", address(uupsProxy));
        console2.log("CounterLogic impl", address(counterImpl));
        console2.log("ProxyAdmin", address(proxyAdmin));
        console2.log("Transparent proxy", address(transparentProxy));
        console2.log("INITIAL_VALUE", initialValue);
    }
}
