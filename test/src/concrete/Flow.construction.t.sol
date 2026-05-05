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
