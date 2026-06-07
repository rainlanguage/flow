// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {IFlowV6} from "../../../src/interface/IFlowV6.sol";
import {EvaluableV4} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV2.sol";
import {IInterpreterV4, StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

contract FlowMulticallTest is FlowTest {
    using LibUint256Matrix for uint256[];

    /// In V4 there is no encoded dispatch, so a per-flow `eval4` mock keyed on
    /// the expression no longer differentiates the two flows. The multicall calls
    /// `eval4` once per flow in order, so a sequential mock returns flow A's stack
    /// to the first call and flow B's stack to the second. Kept in a helper to
    /// avoid "stack too deep" in the test body.
    function mockBothFlows(address flow, address bob, uint256 tokenId, uint256 amount) internal {
        (uint256[] memory stackA,) =
            mintAndBurnFlowStack(bob, 20 ether, 10 ether, 5, transfersERC20toERC20(bob, flow, amount, amount));
        (uint256[] memory stackB,) = mintAndBurnFlowStack(
            bob, 20 ether, 10 ether, 5, transferERC721ToERC1155(flow, bob, tokenId, amount, tokenId)
        );
        StackItem[] memory sA;
        StackItem[] memory sB;
        assembly ("memory-safe") {
            sA := stackA
            sB := stackB
        }
        bytes[] memory returns_ = new bytes[](2);
        returns_[0] = abi.encode(sA, new bytes32[](0));
        returns_[1] = abi.encode(sB, new bytes32[](0));
        vm.mockCalls(address(INTERPRETER), abi.encodeWithSelector(IInterpreterV4.eval4.selector), returns_);
    }

    /// @dev Should call multiple flows from same flow contract at once using multicall.
    function testFlowBasicMulticallFlows(
        address bob,
        uint256 tokenId,
        uint256 amount,
        address expressionA,
        address expressionB
    ) external {
        vm.assume(expressionA != expressionB);
        vm.label(bob, "Bob");

        address[] memory expressions = new address[](2);
        expressions[0] = expressionA;
        expressions[1] = expressionB;

        (IFlowV6 flow, EvaluableV4[] memory evaluables) =
            deployFlow(expressions, new uint256[](0).matrixFrom(new uint256[](0)));

        assumeEtchable(bob, address(flow));
        mockBothFlows(address(flow), bob, tokenId, amount);

        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeCall(flow.flow, (evaluables[0], new bytes32[](0), new SignedContextV1[](0)));
        calldatas[1] = abi.encodeCall(flow.flow, (evaluables[1], new bytes32[](0), new SignedContextV1[](0)));

        vm.startPrank(bob);
        Multicall(address(flow)).multicall(calldatas);
    }
}
