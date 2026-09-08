// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";
import {ProxyErrors} from "../src/errors/ProxyErrors.sol";
import {IUUPSUpgradeable} from "../src/interfaces/IUUPSUpgradeable.sol";
import {UUPSCounter} from "../src/mocks/UUPSCounter.sol";
import {UUPSCounterV2} from "../src/mocks/UUPSCounterV2.sol";
import {NonUUPSLogic} from "../src/mocks/NonUUPSLogic.sol";

/**
 * @title UUPSTest
 * @notice Fase 3: Initializable, autorizacion UUPS y upgrade con persistencia.
 */
contract UUPSTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    address internal owner = makeAddr("owner");
    address internal stranger = makeAddr("stranger");

    UUPSCounter internal logicV1;
    ERC1967Proxy internal proxy;
    UUPSCounter internal asLogic;

    function setUp() public {
        logicV1 = new UUPSCounter();
        bytes memory initData = abi.encodeCall(UUPSCounter.initialize, (owner, 10));
        proxy = new ERC1967Proxy(address(logicV1), initData);
        asLogic = UUPSCounter(address(proxy));
    }

    function test_InitializeSetsStateOnProxy() public view {
        assertEq(asLogic.owner(), owner);
        assertEq(asLogic.value(), 10);
        assertEq(asLogic.version(), "1");
        assertEq(logicV1.owner(), address(0));
        assertEq(logicV1.value(), 0);
    }

    function test_RevertWhen_DoubleInitialize() public {
        vm.expectRevert(ProxyErrors.AlreadyInitialized.selector);
        asLogic.initialize(owner, 1);
    }

    function test_RevertWhen_InitializeOnImplementationDirectly() public {
        UUPSCounter impl = new UUPSCounter();
        vm.expectRevert(ProxyErrors.AlreadyInitialized.selector);
        impl.initialize(owner, 1);
    }

    function test_OwnerUpgradesToV2_PersistsValue() public {
        asLogic.setValue(42);

        UUPSCounterV2 logicV2 = new UUPSCounterV2();
        bytes memory migrate = abi.encodeCall(UUPSCounterV2.initializeV2, ("beta"));

        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(logicV2), migrate);

        UUPSCounterV2 asV2 = UUPSCounterV2(address(proxy));
        assertEq(proxy.implementation(), address(logicV2));
        assertEq(asV2.value(), 42);
        assertEq(asV2.owner(), owner);
        assertEq(asV2.version(), "2");
        assertEq(asV2.label(), "beta");
    }

    function test_RevertWhen_StrangerUpgrades() public {
        UUPSCounterV2 logicV2 = new UUPSCounterV2();
        vm.prank(stranger);
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(logicV2), "");
    }

    function test_RevertWhen_UpgradeCalledOnImplementationNotProxy() public {
        UUPSCounterV2 logicV2 = new UUPSCounterV2();
        vm.prank(owner);
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        logicV1.upgradeToAndCall(address(logicV2), "");
    }

    function test_RevertWhen_NewImplementationIsNotUUPS() public {
        NonUUPSLogic bad = new NonUUPSLogic();
        vm.prank(owner);
        vm.expectRevert(ProxyErrors.InvalidImplementation.selector);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(bad), "");
    }

    function test_RevertWhen_NewImplementationIsZero() public {
        vm.prank(owner);
        vm.expectRevert(ProxyErrors.InvalidImplementation.selector);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(0), "");
    }

    function test_ProxiableUUIDMatchesEip1967Slot() public view {
        assertEq(logicV1.proxiableUUID(), IMPLEMENTATION_SLOT);
    }

    function test_RevertWhen_ProxiableUUIDViaProxy() public {
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        UUPSCounter(address(proxy)).proxiableUUID();
    }

    function test_SetValueThroughProxy() public {
        asLogic.setValue(7);
        assertEq(asLogic.value(), 7);
        assertEq(logicV1.value(), 0);
    }
}
