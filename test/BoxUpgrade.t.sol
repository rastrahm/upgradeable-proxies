// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";
import {IUUPSUpgradeable} from "../src/interfaces/IUUPSUpgradeable.sol";
import {IBox} from "../src/interfaces/IBox.sol";
import {ProxyErrors} from "../src/errors/ProxyErrors.sol";
import {BoxV1} from "../src/implementations/BoxV1.sol";
import {BoxV2} from "../src/implementations/BoxV2.sol";

/**
 * @title BoxUpgradeTest
 * @notice Fase 4: persistencia de storage y compatibilidad de layout V1 → V2 con `__gap`.
 */
contract BoxUpgradeTest is Test {
    address internal owner = makeAddr("owner");
    address internal stranger = makeAddr("stranger");

    BoxV1 internal boxV1Impl;
    ERC1967Proxy internal proxy;
    IBox internal box;

    function setUp() public {
        boxV1Impl = new BoxV1();
        bytes memory initData = abi.encodeCall(IBox.initialize, (owner, 100));
        proxy = new ERC1967Proxy(address(boxV1Impl), initData);
        box = IBox(address(proxy));
    }

    function test_V1InitializeAndStore() public {
        assertEq(box.retrieve(), 100);
        assertEq(box.version(), "1");
        assertEq(BoxV1(address(proxy)).owner(), owner);

        box.store(250);
        assertEq(box.retrieve(), 250);
        assertEq(boxV1Impl.retrieve(), 0, "impl storage must stay empty");
    }

    function test_UpgradeV1ToV2_PersistsOwnerAndValue() public {
        box.store(42);

        BoxV2 boxV2Impl = new BoxV2();
        bytes memory migrate = abi.encodeCall(BoxV2.initializeV2, ("module-11"));

        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(boxV2Impl), migrate);

        BoxV2 asV2 = BoxV2(address(proxy));
        assertEq(proxy.implementation(), address(boxV2Impl));
        assertEq(asV2.retrieve(), 42);
        assertEq(asV2.owner(), owner);
        assertEq(asV2.version(), "2");
        assertEq(asV2.label(), "module-11");
    }

    function test_V2NewLogicAfterUpgrade() public {
        BoxV2 boxV2Impl = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(boxV2Impl), abi.encodeCall(BoxV2.initializeV2, ("x"))
        );

        BoxV2 asV2 = BoxV2(address(proxy));
        asV2.store(7);
        asV2.setLabel("y");
        assertEq(asV2.retrieve(), 7);
        assertEq(asV2.label(), "y");
    }

    function test_RevertWhen_StrangerUpgradesBox() public {
        BoxV2 boxV2Impl = new BoxV2();
        vm.prank(stranger);
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(boxV2Impl), "");
    }

    function test_RevertWhen_DoubleInitializeV1() public {
        vm.expectRevert(ProxyErrors.AlreadyInitialized.selector);
        box.initialize(owner, 1);
    }

    function test_RevertWhen_DoubleInitializeV2() public {
        BoxV2 boxV2Impl = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(boxV2Impl), abi.encodeCall(BoxV2.initializeV2, ("a"))
        );

        vm.expectRevert(ProxyErrors.AlreadyInitialized.selector);
        BoxV2(address(proxy)).initializeV2("b");
    }

    function test_StorageSlotsOwnerAndValueUnchangedAcrossUpgrade() public {
        box.store(999);
        uint256 slot0Before = uint256(vm.load(address(proxy), bytes32(uint256(0))));
        uint256 slot1Before = uint256(vm.load(address(proxy), bytes32(uint256(1))));

        BoxV2 boxV2Impl = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(boxV2Impl), abi.encodeCall(BoxV2.initializeV2, ("gap-ok"))
        );

        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(0)))), slot0Before);
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), slot1Before);
        assertEq(slot1Before, 999);
    }
}
