// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Evaluable, EvaluableConfig} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV1.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV2.sol";
//forge-lint: disable-next-line(unused-import)
import {UnsupportedNativeFlow} from "../v1/IFlowV1.sol";

struct FlowConfig {
    // https://github.com/ethereum/solidity/issues/13597
    EvaluableConfig dummyConfig;
    EvaluableConfig[] config;
}

struct NativeTransfer {
    address from;
    address to;
    uint256 amount;
}

//forge-lint: disable-next-line(pascal-case-struct)
struct ERC20Transfer {
    address token;
    address from;
    address to;
    uint256 amount;
}

//forge-lint: disable-next-line(pascal-case-struct)
struct ERC721Transfer {
    address token;
    address from;
    address to;
    uint256 id;
}

//forge-lint: disable-next-line(pascal-case-struct)
struct ERC1155Transfer {
    address token;
    address from;
    address to;
    uint256 id;
    uint256 amount;
}

struct FlowTransfer {
    /// WARNING: Native transfers were deprecated due to incompatibilities with
    /// the multicall pattern.
    /// https://samczsun.com/two-rights-might-make-a-wrong/
    NativeTransfer[] native;
    ERC20Transfer[] erc20;
    ERC721Transfer[] erc721;
    ERC1155Transfer[] erc1155;
}

interface IFlowV2 {
    event Initialize(address sender, FlowConfig config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowTransfer calldata flowTransfer);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external payable returns (FlowTransfer calldata flowTransfer);
}
