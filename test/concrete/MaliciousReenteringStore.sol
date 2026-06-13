// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IFlowV5} from "../../src/interface/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

/// An interpreter store whose `set` callback re-enters `flow.flow(...)`
/// on the same flow contract. Used to exercise `Flow.flow`'s
/// `nonReentrant` guard against reentry through the store's `set` path.
/// Its `get` returns zero so reads from this store do not crash other
/// callers.
contract MaliciousReenteringStore {
    IFlowV5 internal immutable I_FLOW;
    EvaluableV2 internal evaluable;

    constructor(IFlowV5 flow_) {
        I_FLOW = flow_;
    }

    function setEvaluable(EvaluableV2 memory ev) external {
        evaluable = ev;
    }

    /// Matches `IInterpreterStoreV2.set(StateNamespace, uint256[])`. Re-enters
    /// the flow.
    function set(uint256, uint256[] calldata) external {
        I_FLOW.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
    }

    function get(uint256, uint256) external pure returns (uint256) {
        return 0;
    }
}
