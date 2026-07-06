// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IFlowV6} from "src/interface/IFlowV6.sol";
import {EvaluableV4} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV2.sol";

/// An ERC20-shaped token whose `transferFrom` callback re-enters
/// `flow.flow(...)` on the same flow contract. Used to exercise the
/// `nonReentrant` guard on `Flow.flow`.
contract MaliciousReenteringToken {
    IFlowV6 internal immutable I_FLOW;
    EvaluableV4 internal evaluable;

    constructor(IFlowV6 flow_) {
        I_FLOW = flow_;
    }

    function setEvaluable(EvaluableV4 memory ev) external {
        evaluable = ev;
    }

    /// Re-enters `flow.flow` from inside the ERC20 `transferFrom` path. If
    /// `Flow.flow`'s `nonReentrant` guard is in place the inner call will
    /// revert with `ReentrancyGuardReentrantCall()` and bubble up.
    //forge-lint: disable-next-line(mixed-case-function)
    function transferFrom(address, address, uint256) external returns (bool) {
        I_FLOW.flow(evaluable, new bytes32[](0), new SignedContextV1[](0));
        return true;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
}
