// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";

import {FlowTransferV1, RAIN_FLOW_SENTINEL} from "src/interface/IFlowV5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {FlowTransferOperation} from "test/abstract/FlowTransferOperation.sol";

/// Convenience wrappers around `LibStackGeneration` and `LibLogHelper` so
/// test contracts inheriting this base can call `generateFlowStack` /
/// `findEvent` / `findEvents` directly without re-importing the libraries
/// or re-declaring `using` clauses.
abstract contract FlowUtilsAbstractTest is FlowTransferOperation {
    using LibStackGeneration for uint256;
    using LibLogHelper for Vm.Log[];

    function generateFlowStack(FlowTransferV1 memory flowTransfer) internal pure returns (uint256[] memory stack) {
        stack = Sentinel.unwrap(RAIN_FLOW_SENTINEL).generateFlowStack(flowTransfer);
    }

    function findEvent(Vm.Log[] memory logs, bytes32 eventSignature) internal pure returns (Vm.Log memory) {
        return logs.findEvent(eventSignature);
    }

    function findEvents(Vm.Log[] memory logs, bytes32 eventSignature)
        internal
        pure
        returns (Vm.Log[] memory foundLogs)
    {
        foundLogs = logs.findEvents(eventSignature);
    }
}
