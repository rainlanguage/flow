// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IFlowV5} from "src/interface/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

/// An ERC20-shaped token whose `transferFrom` callback re-enters
/// `flow.flow(...)` on the same flow contract. Used to exercise the
/// `nonReentrant` guard on `Flow.flow`.
contract MaliciousReenteringToken {
    IFlowV5 internal immutable I_FLOW;
    EvaluableV2 internal evaluable;

    constructor(IFlowV5 flow_) {
        I_FLOW = flow_;
    }

    function setEvaluable(EvaluableV2 memory ev) external {
        evaluable = ev;
    }

    /// Re-enters `flow.flow` from inside the ERC20 `transferFrom` path. If
    /// `Flow.flow`'s `nonReentrant` guard is in place the inner call will
    /// revert with `"ReentrancyGuard: reentrant call"` and bubble up.
    //forge-lint: disable-next-line(mixed-case-function)
    function transferFrom(address, address, uint256) external returns (bool) {
        I_FLOW.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        return true;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
}
