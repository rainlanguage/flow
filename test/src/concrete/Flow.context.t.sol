// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {IFlowV5} from "../../../src/interface/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FLOW_MAX_OUTPUTS, FLOW_ENTRYPOINT} from "../../../src/concrete/Flow.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";

contract FlowContextTest is FlowTest {
    /**
     * @dev Tests context handling during interpreter call, ensuring proper input and output management.
     */
    function testFlowBasicInterpreterContextInputOutputManagement(address alice, uint256[] memory callerContext)
        public
    {
        SignedContextV1[] memory signedContext = new SignedContextV1[](0);
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        uint256[][] memory context =
            LibContextWrapper.buildAndSetContext(callerContext, signedContext, address(alice), address(flow));

        {
            uint256[] memory stack = generateFlowStack(transferEmpty());

            interpreterEval2MockCall(stack, new uint256[](0));

            interpreterEval2ExpectCall(
                address(flow),
                LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
                context
            );
        }
        vm.startPrank(alice);
        flow.flow(evaluable, callerContext, signedContext);
        vm.stopPrank();
    }
}
