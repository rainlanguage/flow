// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {SignedContextV1, EvaluableV4} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
//forge-lint: disable-next-line(unused-import)
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
//forge-lint: disable-next-line(unused-import)
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {
    FlowTransferV1,
    //forge-lint: disable-next-line(unused-import)
    ERC20Transfer,
    //forge-lint: disable-next-line(unused-import)
    ERC721Transfer,
    //forge-lint: disable-next-line(unused-import)
    ERC1155Transfer,
    //forge-lint: disable-next-line(unused-import)
    RAIN_FLOW_SENTINEL,
    //forge-lint: disable-next-line(unused-import)
    MIN_FLOW_SENTINELS
} from "./deprecated/v4/IFlowV4.sol";
//forge-lint: disable-next-line(unused-import)
import {UnregisteredFlow} from "../error/ErrFlow.sol";

/// @title IFlowV6
/// @notice V4-interpreter flow: evaluables carry bytecode directly (no expression
/// deployment), context + stack are bytes32-based.
interface IFlowV6 {
    function stackToFlow(StackItem[] memory stack) external pure returns (FlowTransferV1 memory flowTransfer);
    function flow(
        EvaluableV4 calldata evaluable,
        bytes32[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowTransferV1 memory flowTransfer);
}
