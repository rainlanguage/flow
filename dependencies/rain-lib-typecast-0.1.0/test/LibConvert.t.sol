// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibConvert} from "../src/LibConvert.sol";
import {LibConvertSlow} from "./LibConvertSlow.sol";

contract LibConvertTest is Test {
    function testUnsafeToBytesReferenceImplementation(uint256[] memory us) public pure {
        assertEq(
            // Note the order of these calls is important because the unsafe call
            // is unsafe, i.e. the `us` can no longer be used.
            LibConvertSlow.toBytesSlow(us),
            LibConvert.unsafeToBytes(us)
        );
    }

    function testUnsafeTo16BitBytesReferenceImplementation(uint256[] memory us) public pure {
        assertEq(
            // Note the order of these calls is important because the unsafe call
            // is unsafe, i.e. the `us` can no longer be used.
            LibConvertSlow.to16BitBytesSlow(us),
            LibConvert.unsafeTo16BitBytes(us)
        );
    }
}
