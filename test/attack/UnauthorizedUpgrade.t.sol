// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC1967Proxy} from "../../src/proxy/ERC1967Proxy.sol";
import {TransparentProxy} from "../../src/proxy/TransparentProxy.sol";
import {ProxyAdmin} from "../../src/proxy/ProxyAdmin.sol";
import {ITransparentProxy} from "../../src/interfaces/ITransparentProxy.sol";
import {IUUPSUpgradeable} from "../../src/interfaces/IUUPSUpgradeable.sol";
import {IBox} from "../../src/interfaces/IBox.sol";
import {ProxyErrors} from "../../src/errors/ProxyErrors.sol";
import {BoxV1} from "../../src/implementations/BoxV1.sol";
import {BoxV2} from "../../src/implementations/BoxV2.sol";
import {CounterLogic} from "../../src/mocks/CounterLogic.sol";
import {CounterLogicV2} from "../../src/mocks/CounterLogicV2.sol";
import {NonUUPSLogic} from "../../src/mocks/NonUUPSLogic.sol";
import {ICounterLogic} from "../../src/interfaces/ICounterLogic.sol";

/**
 * @title UnauthorizedUpgradeAttackTest
 * @notice Fase 5 / SWC-123: intentos de upgrade y takeover no autorizados.
 */
contract UnauthorizedUpgradeAttackTest is Test {
    address internal owner = makeAddr("owner");
    address internal attacker = makeAddr("attacker");

    function test_Attack_UUPS_StrangerCannotUpgrade() public {
        BoxV1 v1 = new BoxV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(IBox.initialize, (owner, 1)));
        BoxV2 v2 = new BoxV2();

        vm.prank(attacker);
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(v2), "");
    }

    function test_Attack_UUPS_CannotUpgradeOnImplementation() public {
        BoxV1 v1 = new BoxV1();
        BoxV2 v2 = new BoxV2();
        vm.prank(owner);
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        v1.upgradeToAndCall(address(v2), "");
    }

    function test_Attack_UUPS_CannotInitializeImplementation() public {
        BoxV1 v1 = new BoxV1();
        vm.expectRevert(ProxyErrors.AlreadyInitialized.selector);
        v1.initialize(attacker, 999);
    }

    function test_Attack_UUPS_CannotUpgradeToNonProxiable() public {
        BoxV1 v1 = new BoxV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(IBox.initialize, (owner, 1)));
        NonUUPSLogic bad = new NonUUPSLogic();

        vm.prank(owner);
        vm.expectRevert(ProxyErrors.InvalidImplementation.selector);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(address(bad), "");
    }

    function test_Attack_Transparent_NonOwnerCannotUpgrade() public {
        CounterLogic v1 = new CounterLogic();
        vm.prank(owner);
        ProxyAdmin admin = new ProxyAdmin(owner);
        TransparentProxy proxy = new TransparentProxy(address(v1), address(admin), "");
        CounterLogicV2 v2 = new CounterLogicV2();

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        admin.upgradeAndCall(ITransparentProxy(address(proxy)), address(v2), "");
    }

    function test_Attack_Transparent_AdminCannotCallUserLogic() public {
        CounterLogic v1 = new CounterLogic();
        vm.prank(owner);
        ProxyAdmin admin = new ProxyAdmin(owner);
        TransparentProxy proxy = new TransparentProxy(address(v1), address(admin), "");

        vm.prank(address(admin));
        vm.expectRevert(ProxyErrors.UnauthorizedUpgrade.selector);
        ICounterLogic(address(proxy)).setValue(1);
    }

    function test_Attack_Transparent_DirectUpgradeFromEOADoesNotChangeSlot() public {
        CounterLogic v1 = new CounterLogic();
        vm.prank(owner);
        ProxyAdmin admin = new ProxyAdmin(owner);
        TransparentProxy proxy = new TransparentProxy(address(v1), address(admin), "");
        address beforeImpl = proxy.implementation();

        // EOA no es admin → delegatecall; CounterLogic no tiene upgradeToAndCall → falla routing
        vm.prank(attacker);
        (bool ok,) = address(proxy).call(
            abi.encodeCall(ITransparentProxy.upgradeToAndCall, (makeAddr("fake"), bytes("")))
        );
        assertFalse(ok);
        assertEq(proxy.implementation(), beforeImpl);
    }
}
