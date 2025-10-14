// SPDX-License-Identifier: CAL
pragma solidity ^0.8.25;

import {Test, Vm} from "forge-std/Test.sol";

import {FlowTransferV1, RAIN_FLOW_SENTINEL} from "src/interface/IFlowV5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {FlowTransferOperation} from "test/abstract/FlowTransferOperation.sol";

abstract contract FlowUtilsAbstractTest is FlowTransferOperation {
    using LibStackGeneration for uint256;
    using LibLogHelper for Vm.Log[];

    // A temporary solution for a smooth transition to using libraries.
    function generateFlowStack(FlowTransferV1 memory flowTransfer) internal view returns (uint256[] memory stack) {
        stack = sentinel.generateFlowStack(flowTransfer);
    }

    // A temporary solution for a smooth transition to using libraries.
    function findEvent(Vm.Log[] memory logs, bytes32 eventSignature) internal pure returns (Vm.Log memory) {
        return logs.findEvent(eventSignature);
    }

    // A temporary solution for a smooth transition to using libraries.
    function findEvents(Vm.Log[] memory logs, bytes32 eventSignature)
        internal
        pure
        returns (Vm.Log[] memory foundLogs)
    {
        foundLogs = logs.findEvents(eventSignature);
    }
}
