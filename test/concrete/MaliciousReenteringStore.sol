// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IFlowV6} from "../../src/interface/IFlowV6.sol";
import {EvaluableV4} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV2.sol";

/// An interpreter store whose `set` callback re-enters `flow.flow(...)`
/// on the same flow contract. Used to exercise `Flow.flow`'s
/// `nonReentrant` guard against reentry through the store's `set` path.
/// Its `get` returns zero so reads from this store do not crash other
/// callers.
contract MaliciousReenteringStore {
    IFlowV6 internal immutable I_FLOW;
    EvaluableV4 internal evaluable;

    constructor(IFlowV6 flow_) {
        I_FLOW = flow_;
    }

    function setEvaluable(EvaluableV4 memory ev) external {
        evaluable = ev;
    }

    /// Matches `IInterpreterStoreV3.set(StateNamespace, bytes32[])`. Re-enters
    /// the flow.
    function set(uint256, bytes32[] calldata) external {
        I_FLOW.flow(evaluable, new bytes32[](0), new SignedContextV1[](0));
    }

    function get(uint256, bytes32) external pure returns (bytes32) {
        return 0;
    }
}
