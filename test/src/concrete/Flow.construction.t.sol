// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";

import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {EmptyFlowConfig, UnsupportedFlowInputs} from "src/error/ErrFlow.sol";

contract FlowConstructionTest is FlowTest {
    function testFlowConstructionEmptyConfigReverts() external {
        EvaluableConfigV3[] memory emptyConfig = new EvaluableConfigV3[](0);
        address impl = deployFlowImplementation();
        vm.expectRevert(EmptyFlowConfig.selector);
        I_CLONE_FACTORY.clone(impl, abi.encode(emptyConfig));
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

        Vm.Log memory concreteEvent = findEvent(logs, eventSignature);
        (address sender, EvaluableConfigV3[] memory config) =
            abi.decode(concreteEvent.data, (address, EvaluableConfigV3[]));

        assertEq(sender, address(I_CLONE_FACTORY), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowConfig)), keccak256(abi.encode(config)), "wrong compare Structs");
    }
}
