// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import "rain.interpreter.interface/lib/caller/LibEvaluable.sol";

import "./IFlowV2.sol";

//forge-lint: disable-next-line(pascal-case-struct)
struct FlowERC1155Config {
    string uri;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

//forge-lint: disable-next-line(pascal-case-struct)
struct ERC1155SupplyChange {
    address account;
    uint256 id;
    uint256 amount;
}

//forge-lint: disable-next-line(pascal-case-struct)
struct FlowERC1155IO {
    ERC1155SupplyChange[] mints;
    ERC1155SupplyChange[] burns;
    FlowTransfer flow;
}

/// @title IFlowERC1155V2
interface IFlowERC1155V2 {
    event Initialize(address sender, FlowERC1155Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC1155IO calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external payable returns (FlowERC1155IO calldata);
}
