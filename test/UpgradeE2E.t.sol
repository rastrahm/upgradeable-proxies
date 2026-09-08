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
 * @title UpgradeE2ETest
 * @notice Fase 5: ciclo completo deploy → mutate → upgrade → assert (UUPS Box + Transparent).
 */
contract UpgradeE2ETest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function test_E2E_UUPS_Box_DeployMutateUpgradeVerify() public {
        BoxV1 v1 = new BoxV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(IBox.initialize, (owner, 1)));
        IBox box = IBox(address(proxy));

        vm.prank(user);
        box.store(111);
        assertEq(box.retrieve(), 111);

        BoxV2 v2 = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(v2), abi.encodeCall(BoxV2.initializeV2, ("e2e"))
        );

        BoxV2 asV2 = BoxV2(address(proxy));
        assertEq(asV2.retrieve(), 111);
        assertEq(asV2.owner(), owner);
        assertEq(asV2.label(), "e2e");
        assertEq(asV2.version(), "2");
        assertEq(
            address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))), address(v2)
        );
    }

    function test_E2E_Transparent_DeployMutateUpgradeVerify() public {
        CounterLogic v1 = new CounterLogic();
        vm.prank(owner);
        ProxyAdmin admin = new ProxyAdmin(owner);
        TransparentProxy proxy = new TransparentProxy(address(v1), address(admin), "");
        ICounterLogic logic = ICounterLogic(address(proxy));

        vm.prank(user);
        logic.setValue(222);
        assertEq(logic.value(), 222);

        CounterLogicV2 v2 = new CounterLogicV2();
        vm.prank(owner);
        admin.upgradeAndCall(ITransparentProxy(address(proxy)), address(v2), "");

        assertEq(ICounterLogic(address(proxy)).value(), 222);
        assertEq(CounterLogicV2(address(proxy)).version(), "2");
        assertEq(proxy.implementation(), address(v2));
    }

    function test_E2E_StorageLayout_OwnerValueSlotsStable() public {
        BoxV1 v1 = new BoxV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(IBox.initialize, (owner, 5)));
        IBox(address(proxy)).store(777);

        uint256 s0 = uint256(vm.load(address(proxy), bytes32(uint256(0))));
        uint256 s1 = uint256(vm.load(address(proxy), bytes32(uint256(1))));

        BoxV2 v2 = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(v2), abi.encodeCall(BoxV2.initializeV2, ("layout"))
        );

        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(0)))), s0);
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), s1);
        assertEq(s1, 777);
        assertEq(BoxV2(address(proxy)).label(), "layout");
    }
}
