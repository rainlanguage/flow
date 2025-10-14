// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";

import {FlowTest} from "test/abstract/FlowTest.sol";
import {IFlowV5} from "src/interface/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {IInterpreterCallerV2} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";

contract FlowExpressionTest is FlowTest, IInterpreterCallerV2 {
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
    using LibContextWrapper for uint256[][];

    /**
     * @dev Tests that the addresses of expressions emitted in the event
     *      match the addresses provided by the deployer.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasicShouldDeployExpression(address[] memory expressions) public {
        uint256 length = bound(expressions.length, 0, 10);
        assembly ("memory-safe") {
            mstore(expressions, length)
        }

        uint256[][] memory constants = new uint256[][](expressions.length);

        (, EvaluableV2[] memory evaluables) = deployFlow(expressions, constants);

        for (uint256 i = 0; i < evaluables.length; i++) {
            assertEq(evaluables[i].expression, expressions[i]);
        }
    }

    /**
     * @dev Validates that the context emitted in the event matches the expected values.
     */
    /// forge-config: default.fuzz.runs = 100
    function testShouldValidateContextFromEvent(
        uint256 fuzzedKeyAlice,
        uint256[] memory fuzzedcallerContext0,
        uint256[] memory fuzzedcallerContext1
    ) public {
        uint256[][] memory matrixCallerContext =
            fuzzedcallerContext0.matrixFrom(fuzzedcallerContext1, fuzzedcallerContext0);

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        SignedContextV1[] memory signedContext = new SignedContextV1[](matrixCallerContext.length);
        {
            // Ensure the fuzzed key is within the valid range for secp256k1
            uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
            for (uint256 i = 0; i < matrixCallerContext.length; i++) {
                signedContext[i] = vm.signContext(aliceKey, aliceKey, matrixCallerContext[i]);
            }

            (uint256[] memory stack,) = mintAndBurnFlowStack(vm.addr(aliceKey), 20 ether, 10 ether, 5, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));

            vm.recordLogs();
            flow.flow(evaluable, fuzzedcallerContext0, signedContext);
        }

        {
            uint256[][] memory buildContextInput = LibContextWrapper.buildAndSetContext(
                fuzzedcallerContext0.matrixFrom(), signedContext, address(this), address(flow)
            );

            Vm.Log[] memory logs = vm.getRecordedLogs();
            Vm.Log memory log = findEvent(logs, keccak256("Context(address,uint256[][])"));
            (address sender, uint256[][] memory buildContextOutput) = abi.decode(log.data, (address, uint256[][]));

            assertEq(sender, address(this), "wrong sender");
            assertEq(
                keccak256(abi.encode(buildContextInput)),
                keccak256(abi.encode(buildContextOutput)),
                "wrong compare  Context Input Output"
            );
        }
    }
}
