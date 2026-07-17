// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {IFlowV6, RAIN_FLOW_SENTINEL} from "../../../src/interface/IFlowV6.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {EvaluableV4} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FLOW_MAX_OUTPUTS, FLOW_ENTRYPOINT} from "../../../src/concrete/Flow.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV2.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract FlowContextTest is FlowTest {
    /**
     * @dev Tests context handling during interpreter call, ensuring proper input and output management.
     */
    function testFlowBasicInterpreterContextInputOutputManagement(address alice, uint256[] memory callerContext)
        public
    {
        SignedContextV1[] memory signedContext = new SignedContextV1[](0);
        vm.label(alice, "Alice");

        (IFlowV6 flow, EvaluableV4 memory evaluable) = deployFlow();

        uint256[][] memory context =
            LibContextWrapper.buildAndSetContext(callerContext, signedContext, address(alice), address(flow));

        {
            uint256[] memory stack =
                LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transferEmpty());

            interpreterEval2MockCall(stack, new uint256[](0));

            interpreterEval2ExpectCall(address(flow), context);
        }
        vm.startPrank(alice);
        flow.flow(evaluable, asBytes32(callerContext), signedContext);
        vm.stopPrank();
    }
}
