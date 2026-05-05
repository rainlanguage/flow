// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";

import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {EmptyFlowConfig} from "src/error/ErrFlow.sol";
import {ICloneableV2} from "rain.factory/src/interface/ICloneableV2.sol";
import {Flow} from "src/concrete/Flow.sol";

contract FlowConstructionTest is FlowTest {
    function testFlowConstructionEmptyConfigReverts() external {
        EvaluableConfigV3[] memory emptyConfig = new EvaluableConfigV3[](0);
        address impl = deployFlowImplementation();
        vm.expectRevert(EmptyFlowConfig.selector);
        I_CLONE_FACTORY.clone(impl, abi.encode(emptyConfig));
    }

    /// The typed `initialize(EvaluableConfigV3[])` overload is mandated by
    /// `ICloneableV2` to revert with `InitializeSignatureFn` so that it is
    /// NEVER accidentally called in place of the canonical `initialize(bytes)`.
    /// forge-config: default.fuzz.runs = 100
    function testFlowImplementationInitializeStructOverloadAlwaysReverts(EvaluableConfigV3[] memory evaluableConfigs)
        external
    {
        Flow impl = Flow(deployFlowImplementation());
        vm.expectRevert(ICloneableV2.InitializeSignatureFn.selector);
        impl.initialize(evaluableConfigs);
    }

    /// The typed overload must revert even on an already-initialized clone.
    /// forge-config: default.fuzz.runs = 100
    function testFlowCloneInitializeStructOverloadAlwaysReverts(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants,
        EvaluableConfigV3[] memory secondCallConfigs
    ) external {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        address clone = I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        vm.expectRevert(ICloneableV2.InitializeSignatureFn.selector);
        Flow(clone).initialize(secondCallConfigs);
    }

    /// `_disableInitializers` in the implementation constructor must block
    /// any direct `initialize(bytes)` call on the implementation.
    /// forge-config: default.fuzz.runs = 100
    function testFlowImplementationInitializeBytesAlwaysReverts(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants
    ) external {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        Flow impl = Flow(deployFlowImplementation());
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        impl.initialize(abi.encode(flowConfig));
    }

    /// A successfully initialized clone must reject a second
    /// `initialize(bytes)` call.
    /// forge-config: default.fuzz.runs = 100
    function testFlowCloneInitializeBytesOnceOnly(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants
    ) external {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        address clone = I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        Flow(clone).initialize(abi.encode(flowConfig));
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
}
