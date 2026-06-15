// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {RAIN_FLOW_SENTINEL, MIN_FLOW_SENTINELS} from "../../src/interface/IFlowV5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";

contract IFlowV5Test is Test {
    /// `IFlowV5` re-exports `RAIN_FLOW_SENTINEL` from `IFlowV4`. This pins the
    /// value through the V5 re-export surface so a change to the V5 re-export
    /// (intentional or accidental) is caught here, not silently passed through
    /// by importing the V4 constant directly.
    function testSentinelValue() external {
        assertEq(
            0xfea74d0c9bf4a3c28f0dd0674db22a3d7f8bf259c56af19f4ac1e735b156974f, Sentinel.unwrap(RAIN_FLOW_SENTINEL)
        );
    }

    /// `IFlowV5` also re-exports `MIN_FLOW_SENTINELS`. The three required
    /// sentinels (ERC20, ERC721, ERC1155 sections) make this `3`. Pinning it
    /// through the V5 interface guards the re-export the same way as the
    /// sentinel value above.
    function testMinFlowSentinelsValue() external {
        assertEq(MIN_FLOW_SENTINELS, 3);
    }
}
