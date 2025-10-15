// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {EvaluableConfig, FlowTransfer, Evaluable} from "./IFlowV2.sol";

/// Constructor config.
/// @param Constructor config for the ERC721 token minted according to flow
/// schedule in `flow`.
/// @param Constructor config for the `ImmutableSource` that defines the
/// emissions schedule for claiming.
//forge-lint: disable-next-line(pascal-case-struct)
struct FlowERC721Config {
    string name;
    string symbol;
    string baseURI;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

//forge-lint: disable-next-line(pascal-case-struct)
struct ERC721SupplyChange {
    address account;
    uint256 id;
}

//forge-lint: disable-next-line(pascal-case-struct)
struct FlowERC721IO {
    ERC721SupplyChange[] mints;
    ERC721SupplyChange[] burns;
    FlowTransfer flow;
}

/// @title IFlowERC721V2
//forge-lint: disable-next-line(pascal-case-struct)
interface IFlowERC721V2 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC721IO calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external payable returns (FlowERC721IO calldata);
}
