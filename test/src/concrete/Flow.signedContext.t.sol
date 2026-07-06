// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {IFlowV6, RAIN_FLOW_SENTINEL} from "../../../src/interface/IFlowV6.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {EvaluableV4, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract FlowSignedContextTest is FlowTest {
    using SignContextLib for Vm;

    /// Should validate multiple signed contexts
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasicValidateMultipleSignedContexts(
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        (IFlowV6 flow, EvaluableV4 memory evaluable) = deployFlow();

        uint256 aliceKey = boundPrivateKey(fuzzedKeyAlice);
        uint256 bobKey = boundPrivateKey(fuzzedKeyBob);
        // `boundPrivateKey` is not injective over the full uint256 domain, so
        // distinct fuzz inputs can fold onto the same key. The bad-signature
        // assertion below only holds when the two keys actually differ, so
        // constrain the bounded keys (not the raw inputs).
        vm.assume(aliceKey != bobKey);

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);

        signedContexts[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts[1] = vm.signContext(aliceKey, aliceKey, context1);

        uint256[] memory stack =
            LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transferEmpty());

        interpreterEval2MockCall(stack, new uint256[](0));
        flow.flow(evaluable, new bytes32[](0), signedContexts);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts1[1] = vm.signContext(aliceKey, bobKey, context1);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 1));
        flow.flow(evaluable, new bytes32[](0), signedContexts1);
    }

    /// Should validate a signed context
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasicValidateSignedContexts(
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        (IFlowV6 flow, EvaluableV4 memory evaluable) = deployFlow();

        uint256 aliceKey = boundPrivateKey(fuzzedKeyAlice);
        uint256 bobKey = boundPrivateKey(fuzzedKeyBob);
        // `boundPrivateKey` is not injective over the full uint256 domain, so
        // distinct fuzz inputs can fold onto the same key. The bad-signature
        // assertion below only holds when the two keys actually differ, so
        // constrain the bounded keys (not the raw inputs).
        vm.assume(aliceKey != bobKey);

        SignedContextV1[] memory signedContext = new SignedContextV1[](1);
        signedContext[0] = vm.signContext(aliceKey, aliceKey, context0);

        uint256[] memory stack =
            LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transferEmpty());
        interpreterEval2MockCall(stack, new uint256[](0));
        flow.flow(evaluable, new bytes32[](0), signedContext);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContext1 = new SignedContextV1[](1);
        signedContext1[0] = vm.signContext(aliceKey, bobKey, context0);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 0));
        flow.flow(evaluable, new bytes32[](0), signedContext1);
    }
}
