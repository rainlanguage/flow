// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {IInterpreterStoreV3} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {
    IInterpreterV4,
    StackItem,
    DEFAULT_STATE_NAMESPACE
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibNamespace, StateNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";

abstract contract InterpreterMockTest is Test {
    using LibNamespace for StateNamespace;

    IInterpreterV4 constant INTERPRETER = IInterpreterV4(address(uint160(uint256(keccak256("interpreter.rain.test")))));
    IInterpreterStoreV3 constant STORE = IInterpreterStoreV3(address(uint160(uint256(keccak256("store.rain.test")))));

    constructor() {
        vm.pauseGasMetering();
        vm.etch(address(INTERPRETER), REVERTING_MOCK_BYTECODE);
        vm.etch(address(STORE), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    /// Mock `eval4` to return the given stack/writes. Provided as `uint256[]`
    /// for convenience and reinterpreted as `StackItem[]` / `bytes32[]`
    /// (identical 32-byte memory layout).
    function interpreterEval2MockCall(uint256[] memory stack, uint256[] memory writes) internal {
        StackItem[] memory s;
        bytes32[] memory w;
        assembly ("memory-safe") {
            s := stack
            w := writes
        }
        vm.mockCall(address(INTERPRETER), abi.encodeWithSelector(IInterpreterV4.eval4.selector), abi.encode(s, w));
    }

    /// Expect that `eval4` is called on the interpreter. V4 has no encoded
    /// dispatch; the bytecode + source index live inside the `EvalV4` calldata,
    /// so callers match on the selector.
    function interpreterEval2ExpectCall(address, uint256[][] memory) internal {
        vm.expectCall(address(INTERPRETER), abi.encodeWithSelector(IInterpreterV4.eval4.selector));
    }

    /// Mock `eval4` to revert.
    function interpreterEval2RevertCall(address, uint256[][] memory) internal {
        vm.mockCallRevert(
            address(INTERPRETER), abi.encodeWithSelector(IInterpreterV4.eval4.selector), "REVERT_EVAL4_CALL"
        );
    }
}
