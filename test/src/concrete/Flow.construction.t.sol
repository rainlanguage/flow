// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";

import {EvaluableV4} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {EmptyFlowConfig} from "../../../src/error/ErrFlow.sol";
import {Flow} from "../../../src/concrete/Flow.sol";
import {ICloneableV2} from "rain.factory/src/interface/ICloneableV2.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";

contract FlowConstructionTest is FlowTest {
    using LibLogHelper for Vm.Log[];

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

    /// The typed `initialize(EvaluableV4[])` overload is mandated by
    /// `ICloneableV2` to revert with `InitializeSignatureFn` so that it is
    /// NEVER accidentally called in place of the canonical `initialize(bytes)`.
    /// forge-config: default.fuzz.runs = 100
    function testFlowImplementationInitializeStructOverloadAlwaysReverts(EvaluableV4[] memory evaluables) external {
        Flow impl = Flow(deployFlowImplementation());
        vm.expectRevert(ICloneableV2.InitializeSignatureFn.selector);
        impl.initialize(evaluables);
    }

    /// The typed overload must revert even on an already-initialized clone.
    /// forge-config: default.fuzz.runs = 100
    function testFlowCloneInitializeStructOverloadAlwaysReverts(
        bytes memory bytecode,
        EvaluableV4[] memory secondCallEvaluables
    ) external {
        EvaluableV4[] memory flowConfig = new EvaluableV4[](1);
        flowConfig[0] = EvaluableV4(INTERPRETER, STORE, bytecode);

        address clone = I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        vm.expectRevert(ICloneableV2.InitializeSignatureFn.selector);
        Flow(clone).initialize(secondCallEvaluables);
    }

    /// `_disableInitializers` in the implementation constructor must block
    /// any direct `initialize(bytes)` call on the implementation.
    /// forge-config: default.fuzz.runs = 100
    function testFlowImplementationInitializeBytesAlwaysReverts(bytes memory bytecode) external {
        EvaluableV4[] memory flowConfig = new EvaluableV4[](1);
        flowConfig[0] = EvaluableV4(INTERPRETER, STORE, bytecode);

        Flow impl = Flow(deployFlowImplementation());
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(abi.encode(flowConfig));
    }

    /// A successfully initialized clone must reject a second
    /// `initialize(bytes)` call.
    /// forge-config: default.fuzz.runs = 100
    function testFlowCloneInitializeBytesOnceOnly(bytes memory bytecode) external {
        EvaluableV4[] memory flowConfig = new EvaluableV4[](1);
        flowConfig[0] = EvaluableV4(INTERPRETER, STORE, bytecode);

        address clone = I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        Flow(clone).initialize(abi.encode(flowConfig));
    }

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

    /// `flowInit` does not de-duplicate identical evaluables: two evaluables
    /// with the same `(interpreter, store, bytecode)` triple emit two
    /// `FlowInitialized` events and write the same `registeredFlows` slot
    /// twice. The registration is idempotent so the resulting clone is still
    /// functional with that evaluable.
    /// forge-config: default.fuzz.runs = 100
    function testFlowConstructionDuplicateEvaluablesEmitTwiceIdempotently(bytes memory bytecode) external {
        EvaluableV4[] memory flowConfig = new EvaluableV4[](2);
        flowConfig[0] = EvaluableV4(INTERPRETER, STORE, bytecode);
        flowConfig[1] = EvaluableV4(INTERPRETER, STORE, bytecode);

        vm.recordLogs();
        I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        Vm.Log[] memory init =
            vm.getRecordedLogs().findEvents(keccak256("FlowInitialized(address,(address,address,bytes))"));
        assertEq(init.length, 2, "duplicate configs MUST emit two FlowInitialized events");

        (, EvaluableV4 memory ev0) = abi.decode(init[0].data, (address, EvaluableV4));
        (, EvaluableV4 memory ev1) = abi.decode(init[1].data, (address, EvaluableV4));
        assertEq(
            keccak256(abi.encode(ev0)), keccak256(abi.encode(ev1)), "duplicate events MUST carry identical evaluable"
        );
    }

    /// `flowInit` MUST emit one `FlowInitialized(sender, evaluable)` per
    /// registered evaluable, with `sender` equal to the clone-factory caller
    /// and `evaluable` equal to the registered `(interpreter, store,
    /// bytecode)` triple. Pinning this prevents a future change that
    /// drops the event, mismatches the sender, or skips emissions on
    /// duplicate configs.
    /// forge-config: default.fuzz.runs = 100
    function testFlowConstructionEmitsFlowInitializedPerConfig(uint256 lengthSeed) external {
        uint256 length = bound(lengthSeed, 1, 5);

        EvaluableV4[] memory flowConfig = new EvaluableV4[](length);
        for (uint256 i = 0; i < length; i++) {
            // Distinct bytecode per evaluable so each registered flow (and
            // each emitted event payload) is distinct.
            flowConfig[i] = EvaluableV4(INTERPRETER, STORE, abi.encodePacked(uint256(i)));
        }

        vm.recordLogs();
        I_CLONE_FACTORY.clone(deployFlowImplementation(), abi.encode(flowConfig));

        Vm.Log[] memory all = vm.getRecordedLogs();
        Vm.Log[] memory init = all.findEvents(keccak256("FlowInitialized(address,(address,address,bytes))"));

        assertEq(init.length, length, "FlowInitialized count");
        for (uint256 i = 0; i < length; i++) {
            (address sender, EvaluableV4 memory ev) = abi.decode(init[i].data, (address, EvaluableV4));
            assertEq(sender, address(I_CLONE_FACTORY), "FlowInitialized sender");
            assertEq(address(ev.interpreter), address(INTERPRETER), "FlowInitialized interpreter");
            assertEq(address(ev.store), address(STORE), "FlowInitialized store");
            assertEq(keccak256(ev.bytecode), keccak256(abi.encodePacked(uint256(i))), "FlowInitialized bytecode");
        }
    }
}
