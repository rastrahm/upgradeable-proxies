// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Placeholder} from "../src/Placeholder.sol";

/**
 * @title PlaceholderTest
 * @notice Smoke test de Fase 0 (toolchain Foundry).
 */
contract PlaceholderTest is Test {
    function test_ModuleConstant() public {
        Placeholder p = new Placeholder();
        assertEq(p.MODULE(), "11-upgradeable-proxies");
    }
}
