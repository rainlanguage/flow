// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {SourceIndexV2} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterV2.sol";
import {SignedContextV1, EvaluableConfigV3} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV2.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
//forge-lint: disable-next-line(unused-import)
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
//forge-lint: disable-next-line(unused-import)
import {RAIN_FLOW_SENTINEL} from "../../IFlowV5.sol";

import {
    FlowERC1155IOV1,

    //forge-lint: disable-next-line(unused-import)
    ERC1155SupplyChange,

    //forge-lint: disable-next-line(unused-import)
    FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS,

    //forge-lint: disable-next-line(unused-import)
    FLOW_ERC1155_HANDLE_TRANSFER_MIN_OUTPUTS,

    //forge-lint: disable-next-line(unused-import)
    FLOW_ERC1155_MIN_FLOW_SENTINELS
} from "../v4/IFlowERC1155V4.sol";
//forge-lint: disable-next-line(unused-import)
import {UnsupportedHandleTransferInputs, InsufficientHandleTransferOutputs} from "../v3/IFlowERC1155V3.sol";

SourceIndexV2 constant FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT = SourceIndexV2.wrap(0);

/// Initialization config.
/// @param uri As per Open Zeppelin `ERC1155Upgradeable`.
/// @param evaluableConfig Config to use to build the `evaluable` that can be
/// used to handle transfers.
/// @param flowConfig Initialization config for the `Evaluable`s that define the
/// flow behaviours outside self mints/burns.
//forge-lint: disable-next-line(pascal-case-struct)
struct FlowERC1155ConfigV3 {
    string uri;
    EvaluableConfigV3 evaluableConfig;
    EvaluableConfigV3[] flowConfig;
}

/// @title IFlowERC1155V5
/// Conceptually identical to `IFlowV5`, but the flow contract itself is an
/// ERC1155 token. This means that ERC1155 self mints and burns are included in
/// the stack that the flows must evaluate to. As stacks are processed by flow
/// from bottom to top, this means that the self mint/burn will be the last thing
/// evaluated, with mints at the bottom and burns next, followed by the flows.
///
/// As the flow is an ERC1155 token it also includes an evaluation to be run on
/// every token transfer. This is the `handleTransfer` entrypoint. The return
/// stack of this evaluation is ignored, but reverts MUST be respected. This
/// allows expression authors to prevent transfers from occurring if they don't
/// want them to, by reverting within the expression.
///
/// Otherwise the flow contract is identical to `IFlowV5`.
interface IFlowERC1155V5 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC1155ConfigV3 config);

    /// As per `IFlowV4` but returns a `FlowERC1155IOV1` instead of a
    /// `FlowTransferV1`.
    /// @param stack The stack to convert to a `FlowERC1155IOV1`.
    /// @return flowERC1155IO The `FlowERC1155IOV1` representation of the stack.
    //forge-lint: disable-next-line(mixed-case-variable)
    function stackToFlow(uint256[] memory stack) external pure returns (FlowERC1155IOV1 memory flowERC1155IO);

    /// As per `IFlowV4` but returns a `FlowERC1155IOV1` instead of a
    /// `FlowTransferV1` and mints/burns itself as an ERC1155 accordingly.
    /// @param evaluable The `Evaluable` to use to evaluate the flow.
    /// @param callerContext The caller context to use to evaluate the flow.
    /// @param signedContexts The signed contexts to use to evaluate the flow.
    /// @return flowERC1155IO The `FlowERC1155IOV1` representing all token
    /// mint/burns and transfers that occurred during the flow.
    function flow(
        EvaluableV2 calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC1155IOV1 calldata);
}
