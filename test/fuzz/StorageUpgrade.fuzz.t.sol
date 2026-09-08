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
 * @title StorageUpgradeFuzzTest
 * @notice Fase 5: fuzz de estado pre/post upgrade — cero corrupción de slots usados.
 */
contract StorageUpgradeFuzzTest is Test {
    address internal owner = makeAddr("owner");

    /**
     * @notice UUPS Box: `value` y `owner` sobreviven al upgrade con label fuzzed.
     */
    function testFuzz_UUPS_Box_ValuePersistsAfterUpgrade(uint256 initialValue, uint256 mutatedValue)
        public
    {
        initialValue = bound(initialValue, 0, type(uint128).max);
        mutatedValue = bound(mutatedValue, 0, type(uint128).max);

        BoxV1 v1 = new BoxV1();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(v1), abi.encodeCall(IBox.initialize, (owner, initialValue)));
        IBox box = IBox(address(proxy));
        box.store(mutatedValue);

        BoxV2 v2 = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(v2), abi.encodeCall(BoxV2.initializeV2, ("fuzz"))
        );

        BoxV2 asV2 = BoxV2(address(proxy));
        assertEq(asV2.retrieve(), mutatedValue);
        assertEq(asV2.owner(), owner);
        assertEq(asV2.label(), "fuzz");
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), mutatedValue);
    }

    /**
     * @notice Transparent: valor fuzzed persiste al cambiar CounterLogic → V2.
     */
    function testFuzz_Transparent_ValuePersistsAfterUpgrade(uint256 value_) public {
        value_ = bound(value_, 0, type(uint128).max);

        CounterLogic v1 = new CounterLogic();
        vm.prank(owner);
        ProxyAdmin admin = new ProxyAdmin(owner);
        TransparentProxy proxy = new TransparentProxy(address(v1), address(admin), "");
        ICounterLogic(address(proxy)).setValue(value_);

        CounterLogicV2 v2 = new CounterLogicV2();
        vm.prank(owner);
        admin.upgradeAndCall(ITransparentProxy(address(proxy)), address(v2), "");

        assertEq(ICounterLogic(address(proxy)).value(), value_);
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(0)))), value_);
    }

    /**
     * @notice Varias mutaciones + upgrade: el último valor escrito gana y no se corrompe.
     */
    function testFuzz_UUPS_MultiStoreThenUpgrade(uint256 a, uint256 b, uint256 c) public {
        a = bound(a, 0, type(uint64).max);
        b = bound(b, 0, type(uint64).max);
        c = bound(c, 0, type(uint64).max);

        BoxV1 v1 = new BoxV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(IBox.initialize, (owner, a)));
        IBox box = IBox(address(proxy));
        box.store(b);
        box.store(c);

        BoxV2 v2 = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(v2), abi.encodeCall(BoxV2.initializeV2, ("multi"))
        );

        assertEq(BoxV2(address(proxy)).retrieve(), c);
        assertEq(BoxV2(address(proxy)).owner(), owner);
    }

    /**
     * @notice Tras upgrade, nuevas escrituras V2 no pisan `owner` (slot 0).
     */
    function testFuzz_UUPS_PostUpgradeStoreDoesNotClobberOwner(uint256 pre, uint256 post) public {
        pre = bound(pre, 1, type(uint128).max);
        post = bound(post, 0, type(uint128).max);

        BoxV1 v1 = new BoxV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(IBox.initialize, (owner, pre)));

        BoxV2 v2 = new BoxV2();
        vm.prank(owner);
        IUUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(v2), abi.encodeCall(BoxV2.initializeV2, ("safe"))
        );

        BoxV2(address(proxy)).store(post);
        BoxV2(address(proxy)).setLabel("updated");

        assertEq(BoxV2(address(proxy)).owner(), owner);
        assertEq(BoxV2(address(proxy)).retrieve(), post);
        assertEq(BoxV2(address(proxy)).label(), "updated");
    }
}
