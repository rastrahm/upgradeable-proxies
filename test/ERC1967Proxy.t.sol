// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";
import {ProxyErrors} from "../src/errors/ProxyErrors.sol";
import {CounterLogic} from "../src/mocks/CounterLogic.sol";
import {ICounterLogic} from "../src/interfaces/ICounterLogic.sol";

/**
 * @title ERC1967ProxyTest
 * @notice Fase 1: slot EIP-1967, delegatecall y persistencia de estado en el proxy.
 */
contract ERC1967ProxyTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    CounterLogic internal logic;
    ERC1967Proxy internal proxy;
    ICounterLogic internal asLogic;

    function setUp() public {
        logic = new CounterLogic();
        proxy = new ERC1967Proxy(address(logic), "");
        asLogic = ICounterLogic(address(proxy));
    }

    function test_ImplementationSlotMatchesEip1967() public pure {
        assertEq(
            IMPLEMENTATION_SLOT,
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );
        assertEq(
            IMPLEMENTATION_SLOT,
            bytes32(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
        );
    }

    function test_ConstructorStoresImplementationInEip1967Slot() public view {
        assertEq(proxy.implementation(), address(logic));
        assertEq(address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))), address(logic));
    }

    function test_RevertWhen_ImplementationIsZero() public {
        vm.expectRevert(ProxyErrors.InvalidImplementation.selector);
        new ERC1967Proxy(address(0), "");
    }

    function test_RevertWhen_ImplementationHasNoCode() public {
        address eoa = makeAddr("eoa");
        vm.expectRevert(ProxyErrors.InvalidImplementation.selector);
        new ERC1967Proxy(eoa, "");
    }

    function test_DelegatecallWritesStorageOnProxyNotOnLogic() public {
        asLogic.setValue(42);

        assertEq(asLogic.value(), 42);
        assertEq(logic.value(), 0, "impl storage must stay empty");
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(0)))), 42);
    }

    function test_MultipleCallsPersistOnProxy() public {
        asLogic.setValue(10);
        asLogic.increment();
        asLogic.increment();
        assertEq(asLogic.value(), 12);
        assertEq(logic.value(), 0);
    }

    function test_MsgValuePreservedOnDelegatecall() public {
        asLogic.deposit{value: 1 ether}();
        assertEq(asLogic.value(), 1 ether);
        assertEq(address(proxy).balance, 1 ether);
        assertEq(address(logic).balance, 0);
    }

    function test_ConstructorInitDataRunsViaDelegatecall() public {
        CounterLogic logic2 = new CounterLogic();
        bytes memory data = abi.encodeCall(ICounterLogic.setValue, (7));
        ERC1967Proxy p = new ERC1967Proxy(address(logic2), data);
        assertEq(ICounterLogic(address(p)).value(), 7);
        assertEq(logic2.value(), 0);
    }

    function test_RevertWhen_DelegatecallFailsWithEmptyReturndata() public {
        vm.expectRevert(ProxyErrors.DelegateCallFailed.selector);
        asLogic.failEmpty();
    }

    function test_BubblesImplementationRevertReason() public {
        vm.expectRevert(bytes("CounterLogic: fail"));
        asLogic.fail();
    }

    function test_EmitUpgradedOnConstruction() public {
        CounterLogic logic2 = new CounterLogic();
        vm.expectEmit(true, false, false, false);
        emit ERC1967Proxy.Upgraded(address(logic2));
        new ERC1967Proxy(address(logic2), "");
    }
}
