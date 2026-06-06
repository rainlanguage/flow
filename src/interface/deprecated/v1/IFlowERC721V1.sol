// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    EvaluableConfig,
    Evaluable,
    SignedContext
} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV1.sol";
import {FlowTransfer} from "./IFlowV1.sol";

/// Thrown when burner of tokens is not the owner of tokens.
error BurnerNotOwner();

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

/// @title IFlowERC721V1
interface IFlowERC721V1 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContext[] calldata signedContexts
    ) external view returns (FlowERC721IO calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContext[] calldata signedContexts
    ) external payable returns (FlowERC721IO calldata);
}
