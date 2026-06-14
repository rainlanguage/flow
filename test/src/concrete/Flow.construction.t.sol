// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";

import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {EmptyFlowConfig, InsufficientFlowOutputs, UnsupportedFlowInputs} from "../../../src/error/ErrFlow.sol";
import {MIN_FLOW_SENTINELS} from "../../../src/interface/IFlowV5.sol";
import {Flow} from "../../../src/concrete/Flow.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {ICloneableV2} from "rain.factory/src/interface/ICloneableV2.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";

contract FlowConstructionTest is FlowTest {
    using LibLogHelper for Vm.Log[];

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
    function testFlowCloneInitializeBytesOnceOnly(address expression, bytes memory bytecode, uint256[] memory constants)
        external
    {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        address clone = I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        Flow(clone).initialize(abi.encode(flowConfig));
    }

    /// Reverts with `InsufficientFlowOutputs` when the deployer reports a
    /// `flowOutputs` byte below `MIN_FLOW_SENTINELS` (= 3). Pinning this
    /// protects the lower-bound guard at `Flow.flowInit` against regression.
    /// forge-config: default.fuzz.runs = 100
    function testFlowConstructionRevertsOnInsufficientFlowOutputs(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants,
        uint8 flowOutputs
    ) external {
        vm.assume(flowOutputs < uint8(MIN_FLOW_SENTINELS));
        bytes memory io = abi.encodePacked(uint8(0), flowOutputs);
        expressionDeployerDeployExpression2MockCall(expression, io);

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        address impl = deployFlowImplementation();
        vm.expectRevert(InsufficientFlowOutputs.selector);
        I_CLONE_FACTORY.clone(impl, abi.encode(flowConfig));
    }

    /// `flowOutputs == MIN_FLOW_SENTINELS` is the lowest accepted value.
    /// Pinning this boundary against regression complements the negative
    /// test above.
    function testFlowConstructionAcceptsFlowOutputsAtMin(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants
    ) external {
        bytes memory io = abi.encodePacked(uint8(0), uint8(MIN_FLOW_SENTINELS));
        expressionDeployerDeployExpression2MockCall(expression, io);

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));
    }

    /// Reverts with `UnsupportedFlowInputs` when the deployer reports any
    /// non-zero `flowInputs` byte in the IO string. Pinning this protects
    /// against a future deployer behaviour change leaking non-zero inputs
    /// through the guard at `Flow.flowInit`.
    /// forge-config: default.fuzz.runs = 100
    function testFlowConstructionRevertsOnNonZeroFlowInputs(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants,
        uint8 flowInputs
    ) external {
        vm.assume(flowInputs != 0);
        // io: byte0 = flowInputs (non-zero), byte1 = 7 (>= MIN_FLOW_SENTINELS).
        bytes memory io = abi.encodePacked(flowInputs, uint8(7));
        expressionDeployerDeployExpression2MockCall(expression, io);

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(DEPLOYER, bytecode, constants);

        address impl = deployFlowImplementation();
        vm.expectRevert(UnsupportedFlowInputs.selector);
        I_CLONE_FACTORY.clone(impl, abi.encode(flowConfig));
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

        Vm.Log memory concreteEvent = LibLogHelper.findEvent(logs, eventSignature);
        (address sender, EvaluableConfigV3[] memory config) =
            abi.decode(concreteEvent.data, (address, EvaluableConfigV3[]));

        assertEq(sender, address(I_CLONE_FACTORY), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowConfig)), keccak256(abi.encode(config)), "wrong compare Structs");
    }

    /// `flowInit` MUST emit one `FlowInitialized(sender, evaluable)` per
    /// registered config, with `sender` equal to the clone-factory caller
    /// and `evaluable` equal to the deployer-returned `(interpreter, store,
    /// expression)` triple. Pinning this prevents a future change that
    /// drops the event, mismatches the sender, or skips emissions on
    /// duplicate configs.
    /// forge-config: default.fuzz.runs = 100
    function testFlowConstructionEmitsFlowInitializedPerConfig(address[] memory expressions) external {
        uint256 length = bound(expressions.length, 1, 5);
        assembly ("memory-safe") {
            mstore(expressions, length)
        }

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](length);
        for (uint256 i = 0; i < length; i++) {
            // Distinct (bytecode, constants) per config so each call to the
            // deployer mock returns a distinct `expression`.
            bytes memory bytecode = abi.encodePacked(uint256(i));
            uint256[] memory constants = new uint256[](0);
            expressionDeployerDeployExpression2MockCall(bytecode, constants, expressions[i], bytes(hex"0007"));
            flowConfig[i] = EvaluableConfigV3(DEPLOYER, bytecode, constants);
        }

        vm.recordLogs();
        I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        Vm.Log[] memory all = vm.getRecordedLogs();
        Vm.Log[] memory init = all.findEvents(keccak256("FlowInitialized(address,(address,address,address))"));

        assertEq(init.length, length, "FlowInitialized count");
        for (uint256 i = 0; i < length; i++) {
            (address sender, EvaluableV2 memory ev) = abi.decode(init[i].data, (address, EvaluableV2));
            assertEq(sender, address(I_CLONE_FACTORY), "FlowInitialized sender");
            assertEq(address(ev.interpreter), address(INTERPRETER), "FlowInitialized interpreter");
            assertEq(address(ev.store), address(STORE), "FlowInitialized store");
            assertEq(ev.expression, expressions[i], "FlowInitialized expression");
        }
    }
}
