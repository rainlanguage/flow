// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {IFlowV6, RAIN_FLOW_SENTINEL} from "../../../src/interface/IFlowV6.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {EvaluableV4, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterV2.sol";
import {IInterpreterStoreV3} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract FlowTimeTest is FlowTest {
    function testFlowBasicFlowTime(uint256[] memory writeToStore) public {
        vm.assume(writeToStore.length != 0);

        (IFlowV6 flow, EvaluableV4 memory evaluable) = deployFlow();

        uint256[] memory stack =
            LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transferEmpty());

        interpreterEval2MockCall(stack, writeToStore);

        vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV3.set.selector), abi.encode());

        vm.expectCall(
            address(STORE),
            abi.encodeWithSelector(IInterpreterStoreV3.set.selector, DEFAULT_STATE_NAMESPACE, asBytes32(writeToStore))
        );

        flow.flow(evaluable, asBytes32(writeToStore), new SignedContextV1[](0));
    }

    /// `LibFlow.flow` short-circuits the `interpreterStore.set` call when
    /// `kvs.length == 0`. Pin this with an explicit count=0 expectCall so
    /// a future refactor that drops the short-circuit is caught.
    function testFlowBasicFlowTimeNoStoreSetWhenKvsEmpty() public {
        (IFlowV6 flow, EvaluableV4 memory evaluable) = deployFlow();

        uint256[] memory stack =
            LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transferEmpty());
        interpreterEval2MockCall(stack, new uint256[](0));

        // Mock set to a no-op so the existing REVERTING_MOCK_BYTECODE on
        // STORE doesn't accidentally pass the test for the wrong reason.
        vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV3.set.selector), abi.encode());
        vm.expectCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV3.set.selector), 0);

        flow.flow(evaluable, new bytes32[](0), new SignedContextV1[](0));
    }

    /// A revert from `interpreterStore.set` MUST propagate out of `flow`
    /// rather than being caught and swallowed.
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasicFlowTimeStoreSetRevertBubbles(uint256[] memory writeToStore) public {
        vm.assume(writeToStore.length != 0);

        (IFlowV6 flow, EvaluableV4 memory evaluable) = deployFlow();

        uint256[] memory stack =
            LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transferEmpty());
        interpreterEval2MockCall(stack, writeToStore);

        vm.mockCallRevert(address(STORE), abi.encodeWithSelector(IInterpreterStoreV3.set.selector), "STORE_SET_FAILED");

        vm.expectRevert("STORE_SET_FAILED");
        flow.flow(evaluable, asBytes32(writeToStore), new SignedContextV1[](0));
    }
}
