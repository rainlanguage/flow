// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {IFlowV5} from "../../../src/interface/IFlowV5.sol";
import {FLOW_MAX_OUTPUTS, FLOW_ENTRYPOINT} from "../../../src/concrete/Flow.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

contract FlowMulticallTest is FlowTest {
    using LibUint256Matrix for uint256[];

    /**
     * @dev Should call multiple flows from same flow contract at once using multicall
     *
     */
    function testFlowBasicMulticallFlows(
        address bob,
        uint256 tokenId,
        uint256 amount,
        address expressionA,
        address expressionB
    ) external {
        vm.assume(expressionA != expressionB);
        vm.label(bob, "Bob");
        vm.label(expressionA, "expressionA");
        vm.label(expressionB, "expressionB");

        address[] memory expressions = new address[](2);
        expressions[0] = expressionA;
        expressions[1] = expressionB;

        (IFlowV5 flow, EvaluableV2[] memory evaluables) =
            deployFlow(expressions, new uint256[](0).matrixFrom(new uint256[](0)));

        assumeEtchable(bob, address(flow));
        executeFlowA(bob, address(flow), evaluables[0], amount);
        executeFlowB(bob, address(flow), evaluables[1], tokenId, amount);

        {
            bytes[] memory calldatas = new bytes[](2);
            calldatas[0] = abi.encodeCall(flow.flow, (evaluables[0], new uint256[](0), new SignedContextV1[](0)));
            calldatas[1] = abi.encodeCall(flow.flow, (evaluables[1], new uint256[](0), new SignedContextV1[](0)));

            vm.startPrank(bob);
            Multicall(address(flow)).multicall(calldatas);
        }
    }

    function executeFlowA(address bob, address flow, EvaluableV2 memory evaluable, uint256 amount) internal {
        (uint256[] memory stack,) =
            mintAndBurnFlowStack(bob, 20 ether, 10 ether, 5, transfersERC20toERC20(bob, flow, amount, amount));
        interpreterEval2MockCall(
            address(flow),
            LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
            stack,
            new uint256[](0)
        );
    }

    function executeFlowB(address bob, address flow, EvaluableV2 memory evaluable, uint256 tokenId, uint256 amount)
        internal
    {
        (uint256[] memory stack,) = mintAndBurnFlowStack(
            bob, 20 ether, 10 ether, 5, transferERC721ToERC1155(flow, bob, tokenId, amount, tokenId)
        );
        interpreterEval2MockCall(
            flow,
            LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
            stack,
            new uint256[](0)
        );
    }
}
