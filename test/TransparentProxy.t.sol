// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TransparentProxy} from "../src/proxy/TransparentProxy.sol";
import {ProxyAdmin} from "../src/proxy/ProxyAdmin.sol";
import {ITransparentProxy} from "../src/interfaces/ITransparentProxy.sol";
import {ProxyErrors} from "../src/errors/ProxyErrors.sol";
import {CounterLogic} from "../src/mocks/CounterLogic.sol";
import {CounterLogicV2} from "../src/mocks/CounterLogicV2.sol";
import {ClashingLogic} from "../src/mocks/ClashingLogic.sol";
import {ICounterLogic} from "../src/interfaces/ICounterLogic.sol";

/**
 * @title TransparentProxyTest
 * @notice Fase 2: admin vs usuario, ProxyAdmin Ownable2Step y upgrades autorizados.
 */
contract TransparentProxyTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    address internal stranger = makeAddr("stranger");

    ProxyAdmin internal proxyAdmin;
    CounterLogic internal logicV1;
    TransparentProxy internal proxy;
    ICounterLogic internal asLogic;

    function setUp() public {
        logicV1 = new CounterLogic();
        vm.prank(owner);
        proxyAdmin = new ProxyAdmin(owner);
        proxy = new TransparentProxy(address(logicV1), address(proxyAdmin), "");
        asLogic = ICounterLogic(address(proxy));
    }

    function test_AdminSlotMatchesEip1967() public pure {
        assertEq(ADMIN_SLOT, bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        assertEq(ADMIN_SLOT, bytes32(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103));
    }

    function test_ConstructorStoresAdminInEip1967Slot() public view {
        assertEq(proxy.admin(), address(proxyAdmin));
        assertEq(address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))), address(proxyAdmin));
        assertEq(proxy.implementation(), address(logicV1));
    }

    function test_UserCallsDelegateToImplementation() public {
        vm.prank(user);
        asLogic.setValue(99);
        assertEq(asLogic.value(), 99);
        assertEq(logicV1.value(), 0);
    }

    function test_RevertWhen_AdminCallsUserFunction() public {
        vm.prank(address(proxyAdmin));
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        asLogic.setValue(1);
    }

    function test_OwnerUpgradesViaProxyAdmin_PersistsState() public {
        vm.prank(user);
        asLogic.setValue(42);

        CounterLogicV2 logicV2 = new CounterLogicV2();
        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentProxy(address(proxy)), address(logicV2), "");

        assertEq(proxy.implementation(), address(logicV2));
        assertEq(asLogic.value(), 42);
        assertEq(CounterLogicV2(address(proxy)).version(), "2");
    }

    function test_RevertWhen_NonOwnerUpgradesViaProxyAdmin() public {
        CounterLogicV2 logicV2 = new CounterLogicV2();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        proxyAdmin.upgradeAndCall(ITransparentProxy(address(proxy)), address(logicV2), "");
    }

    function test_UserUpgradeSelectorGoesToImplementation_NotProxySlot() public {
        ClashingLogic clash = new ClashingLogic();
        TransparentProxy p = new TransparentProxy(address(clash), address(proxyAdmin), "");

        // Usuario invoca el selector de upgrade → delegatecall a ClashingLogic
        vm.prank(user);
        ITransparentProxy(address(p)).upgradeToAndCall(address(0xBEEF), "");

        assertTrue(ClashingLogic(address(p)).called());
        assertEq(p.implementation(), address(clash), "slot impl no debe cambiar por clash de usuario");
    }

    function test_AdminUpgradeChangesImplementationSlot() public {
        ClashingLogic clash = new ClashingLogic();
        CounterLogicV2 v2 = new CounterLogicV2();
        TransparentProxy p = new TransparentProxy(address(clash), address(proxyAdmin), "");

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentProxy(address(p)), address(v2), "");

        assertEq(p.implementation(), address(v2));
        assertEq(uint256(vm.load(address(p), bytes32(uint256(0)))), 0, "clash flag should not be set");
    }

    function test_UpgradeWithInitData() public {
        CounterLogicV2 v2 = new CounterLogicV2();
        bytes memory data = abi.encodeCall(ICounterLogic.setValue, (7));

        vm.prank(user);
        asLogic.setValue(1);

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentProxy(address(proxy)), address(v2), data);

        assertEq(asLogic.value(), 7);
        assertEq(proxy.implementation(), address(v2));
    }

    function test_TransferProxyAdminOwnership_NewOwnerCanUpgrade() public {
        address newOwner = makeAddr("newOwner");
        CounterLogicV2 v2 = new CounterLogicV2();

        vm.prank(owner);
        proxyAdmin.transferOwnership(newOwner);
        vm.prank(newOwner);
        proxyAdmin.acceptOwnership();

        assertEq(proxyAdmin.owner(), newOwner);
        assertEq(proxy.admin(), address(proxyAdmin), "admin del proxy sigue siendo ProxyAdmin");

        vm.prank(newOwner);
        proxyAdmin.upgradeAndCall(ITransparentProxy(address(proxy)), address(v2), "");
        assertEq(proxy.implementation(), address(v2));
    }

    function test_RevertWhen_ZeroAdminInConstructor() public {
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        new TransparentProxy(address(logicV1), address(0), "");
    }
}
