// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";

import {EvaluableV4} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {EmptyFlowConfig} from "../../../src/error/ErrFlow.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";

contract FlowConstructionTest is FlowTest {
    function testFlowConstructionEmptyConfigReverts() external {
        EvaluableV4[] memory emptyConfig = new EvaluableV4[](0);
        address impl = deployFlowImplementation();
        vm.expectRevert(EmptyFlowConfig.selector);
        I_CLONE_FACTORY.clone(impl, abi.encode(emptyConfig));
    }

    // Note: under the V4 interpreter there is no deploy-time integrity check —
    // evaluables carry bytecode directly with no `deployExpression2`/`io`, so the
    // former `InsufficientFlowOutputs`/`UnsupportedFlowInputs` construction-time
    // guards (and their tests) no longer apply. Flow validity is enforced at eval
    // time via sentinel consumption against `MIN_FLOW_SENTINELS`.

    function testFlowConstructionInitialize(bytes memory bytecode) external {
        EvaluableV4[] memory flowConfig = new EvaluableV4[](1);
        flowConfig[0] = EvaluableV4(INTERPRETER, STORE, bytecode);

        vm.recordLogs();
        I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("Initialize(address,(address,address,bytes)[])");

        Vm.Log memory concreteEvent = LibLogHelper.findEvent(logs, eventSignature);
        (address sender, EvaluableV4[] memory config) = abi.decode(concreteEvent.data, (address, EvaluableV4[]));

        assertEq(sender, address(I_CLONE_FACTORY), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowConfig)), keccak256(abi.encode(config)), "wrong compare Structs");
    }
}
