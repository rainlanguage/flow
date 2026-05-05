// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";

import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {EmptyFlowConfig} from "src/error/ErrFlow.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";

contract FlowConstructionTest is FlowTest {
    using LibLogHelper for Vm.Log[];
    function testFlowConstructionEmptyConfigReverts() external {
        EvaluableConfigV3[] memory emptyConfig = new EvaluableConfigV3[](0);
        address impl = deployFlowImplementation();
        vm.expectRevert(EmptyFlowConfig.selector);
        I_CLONE_FACTORY.clone(impl, abi.encode(emptyConfig));
    }

    function testFlowConstructionInitialize(address expression, bytes memory bytecode, uint256[] memory constants)
        external
    {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        vm.recordLogs();
        I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("Initialize(address,(address,bytes,uint256[])[])");

        Vm.Log memory concreteEvent = findEvent(logs, eventSignature);
        (address sender, EvaluableConfigV3[] memory config) =
            abi.decode(concreteEvent.data, (address, EvaluableConfigV3[]));

        assertEq(sender, address(I_CLONE_FACTORY), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowConfig)), keccak256(abi.encode(config)), "wrong compare Structs");
    }

    /// `flowInit` does not de-duplicate identical evaluable configs: two
    /// configs that produce the same `(interpreter, store, expression)`
    /// triple emit two `FlowInitialized` events and write the same
    /// `registeredFlows` slot twice. The registration is idempotent so
    /// the resulting clone is still functional with that evaluable.
    /// forge-config: default.fuzz.runs = 100
    function testFlowConstructionDuplicateEvaluablesEmitTwiceIdempotently(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants
    ) external {
        expressionDeployerDeployExpression2MockCall(bytecode, constants, expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](2);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);
        flowConfig[1] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        vm.recordLogs();
        I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        Vm.Log[] memory init =
            vm.getRecordedLogs().findEvents(keccak256("FlowInitialized(address,(address,address,address))"));
        assertEq(init.length, 2, "duplicate configs MUST emit two FlowInitialized events");

        (, EvaluableV2 memory ev0) = abi.decode(init[0].data, (address, EvaluableV2));
        (, EvaluableV2 memory ev1) = abi.decode(init[1].data, (address, EvaluableV2));
        assertEq(keccak256(abi.encode(ev0)), keccak256(abi.encode(ev1)), "duplicate events MUST carry identical evaluable");
    }
}
