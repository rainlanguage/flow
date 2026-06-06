// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCast} from "../src/LibCast.sol";

contract LibCastTest is Test {
    function testAddressesArrayRound0(uint256[] memory us) public pure {
        assertEq(us, LibCast.asUint256Array(LibCast.asAddressesArray(us)));
    }

    function testAddressesArrayRound1(address[] memory addresses) public pure {
        assertEq(addresses, LibCast.asAddressesArray(LibCast.asUint256Array(addresses)));
    }

    function testBytes32ArrayRound0(uint256[] memory us) public pure {
        assertEq(us, LibCast.asUint256Array(LibCast.asBytes32Array(us)));
    }

    function testBytes32ArrayRound1(bytes32[] memory b32s) public pure {
        bytes32[] memory round_ = LibCast.asBytes32Array(LibCast.asUint256Array(b32s));

        for (uint256 i = 0; i < b32s.length; i++) {
            assertEq(b32s[i], round_[i]);
        }
    }
}
