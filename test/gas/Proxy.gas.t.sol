// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "../../src/proxy/ERC1967Proxy.sol";
import {TransparentProxy} from "../../src/proxy/TransparentProxy.sol";
import {ProxyAdmin} from "../../src/proxy/ProxyAdmin.sol";
import {ITransparentProxy} from "../../src/interfaces/ITransparentProxy.sol";
import {IUUPSUpgradeable} from "../../src/interfaces/IUUPSUpgradeable.sol";
import {IBox} from "../../src/interfaces/IBox.sol";
import {BoxV1} from "../../src/implementations/BoxV1.sol";
import {BoxV2} from "../../src/implementations/BoxV2.sol";
import {CounterLogic} from "../../src/mocks/CounterLogic.sol";
import {CounterLogicV2} from "../../src/mocks/CounterLogicV2.sol";
import {ICounterLogic} from "../../src/interfaces/ICounterLogic.sol";

/**
 * @title ProxyGasTest
 * @notice Fase 6: benchmarks de hot path (store / upgrade) para `forge test --gas-report`.
 */
contract ProxyGasTest is Test {
    address internal owner = makeAddr("owner");

    BoxV1 internal boxImpl;
    ERC1967Proxy internal uupsProxy;
    IBox internal box;

    ProxyAdmin internal proxyAdmin;
    TransparentProxy internal transparentProxy;
    ICounterLogic internal counter;

    function setUp() public {
        boxImpl = new BoxV1();
        uupsProxy = new ERC1967Proxy(address(boxImpl), abi.encodeCall(IBox.initialize, (owner, 0)));
        box = IBox(address(uupsProxy));

        CounterLogic logic = new CounterLogic();
        vm.prank(owner);
        proxyAdmin = new ProxyAdmin(owner);
        transparentProxy = new TransparentProxy(address(logic), address(proxyAdmin), "");
        counter = ICounterLogic(address(transparentProxy));
    }

    function testGas_UUPS_store() public {
        box.store(1);
    }

    function testGas_UUPS_retrieve() public view {
        box.retrieve();
    }

    function testGas_UUPS_upgradeToV2() public {
        BoxV2 v2 = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(uupsProxy)).upgradeToAndCall(
            address(v2), abi.encodeCall(BoxV2.initializeV2, ("g"))
        );
    }

    function testGas_Transparent_setValue() public {
        counter.setValue(1);
    }

    function testGas_Transparent_value() public view {
        counter.value();
    }

    function testGas_Transparent_upgradeAndCall() public {
        CounterLogicV2 v2 = new CounterLogicV2();
        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentProxy(address(transparentProxy)), address(v2), "");
    }
}
