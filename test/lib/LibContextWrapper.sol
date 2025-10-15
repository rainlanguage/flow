// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";

/**
 * @title ContextBuilder
 * @dev Constructs and emits a structured context array for use in interpreter-based smart contracts.
 * Used in testing to generate and verify context data sent to interpreter.
 */
library LibContextWrapper {
    using LibContext for *;
    using LibUint256Matrix for uint256[];

    function buildAndSetContext(
        uint256[][] memory context,
        SignedContextV1[] memory signedContext,
        address caller,
        address flowAddress
    ) internal view returns (uint256[][] memory) {
        uint256[][] memory buildContextInput = LibContext.build(context, signedContext);
        buildContextInput[0][0] = uint256(uint160(caller));
        buildContextInput[0][1] = uint256(uint160(flowAddress));
        return buildContextInput;
    }

    function buildAndSetContext(
        uint256[] memory context,
        SignedContextV1[] memory signedContext,
        address caller,
        address flowAddress
    ) internal view returns (uint256[][] memory) {
        return buildAndSetContext(context.matrixFrom(), signedContext, caller, flowAddress);
    }
}
