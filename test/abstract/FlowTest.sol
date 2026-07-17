// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";
import {FlowTransferOperation} from "test/abstract/FlowTransferOperation.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {EvaluableV4} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {FlowTransferV1, IFlowV6, RAIN_FLOW_SENTINEL, Sentinel} from "../../src/interface/IFlowV6.sol";
import {Flow} from "../../src/concrete/Flow.sol";
import {StackItem} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";

abstract contract FlowTest is FlowTransferOperation, InterpreterMockTest {
    using LibLogHelper for Vm.Log[];
    using LibStackGeneration for uint256;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];

    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        vm.pauseGasMetering();
        I_CLONE_FACTORY = new CloneFactory();
        vm.resumeGasMetering();
    }

    /// Reinterpret a `uint256[]` as `bytes32[]` (identical 32-byte layout) for
    /// passing as V4 caller context.
    function asBytes32(uint256[] memory a) internal pure returns (bytes32[] memory b) {
        assembly ("memory-safe") {
            b := a
        }
    }

    /// Reinterpret a `uint256[]` stack as `StackItem[]` for V4 `stackToFlow`.
    function asStackItems(uint256[] memory a) internal pure returns (StackItem[] memory b) {
        assembly ("memory-safe") {
            b := a
        }
    }

    /// Build a mock V4 evaluable. There is no expression deployment in V4 — the
    /// evaluable carries bytecode directly. The `expression`/`constants` params
    /// are retained for call-site compatibility but unused (constants are
    /// embedded in bytecode); `bytecode` is unique per flow so registered hashes
    /// differ.
    function expressionDeployer(address, uint256[] memory, bytes memory bytecode)
        internal
        view
        returns (EvaluableV4 memory)
    {
        return EvaluableV4(INTERPRETER, STORE, bytecode);
    }

    function expressionDeployer(uint256 key, address expression, uint256[] memory constants)
        internal
        view
        returns (EvaluableV4 memory)
    {
        return expressionDeployer(expression, constants, abi.encodePacked(expression));
    }

    function deployFlow(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address[] memory expressions,
        address configExpression,
        uint256[][] memory constants
    ) internal returns (address flow, EvaluableV4[] memory evaluables) {
        require(expressions.length == constants.length, "Expressions and constants array lengths must match");

        {
            EvaluableV4[] memory flowConfig = new EvaluableV4[](expressions.length);

            for (uint256 i = 0; i < expressions.length; i++) {
                flowConfig[i] = expressionDeployer(i + 1, expressions[i], constants[i]);
            }

            vm.recordLogs();
            flow = I_CLONE_FACTORY.clone(
                deployFlowImplementation(), buildConfig(name, symbol, baseURI, configExpression, flowConfig)
            );
        }

        {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            logs = logs.findEvents(keccak256("FlowInitialized(address,(address,address,bytes))"));
            evaluables = new EvaluableV4[](logs.length);
            for (uint256 i = 0; i < logs.length; i++) {
                (, EvaluableV4 memory evaluable) = abi.decode(logs[i].data, (address, EvaluableV4));
                evaluables[i] = evaluable;
            }
        }
    }

    function createMockBytecode() internal pure virtual returns (bytes memory) {
        return hex"030002000500080AAA0BBB0CCC";
    }

    function assumeEtchable(address account) internal view {
        assumeEtchable(account, address(0));
    }

    function assumeEtchable(address account, address expression) internal view {
        assumeNotPrecompile(account);
        vm.assume(account != address(INTERPRETER));
        vm.assume(account != address(STORE));
        vm.assume(account != address(I_CLONE_FACTORY));
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != uint256(uint160(account)));
        vm.assume(account != address(expression));
        vm.assume(account.code.length == 0);
        // The console.
        vm.assume(account != address(0x000000000000000000636F6e736F6c652e6c6f67));
    }

    function _buildFlowStack(FlowTransferV1 memory transfer) private pure returns (uint256[] memory, bytes32) {
        bytes32 transferHash = keccak256(abi.encode(transfer));
        uint256[] memory stack = Sentinel.unwrap(RAIN_FLOW_SENTINEL).generateFlowStack(transfer);
        return (stack, transferHash);
    }

    function burnFlowStack(address, uint256, uint256, FlowTransferV1 memory transfer)
        internal
        pure
        returns (uint256[] memory, bytes32)
    {
        return _buildFlowStack(transfer);
    }

    function mintFlowStack(address, uint256, uint256, FlowTransferV1 memory transfer)
        internal
        pure
        returns (uint256[] memory, bytes32)
    {
        return _buildFlowStack(transfer);
    }

    function buildConfig(string memory, string memory, string memory, address, EvaluableV4[] memory flowConfig)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(flowConfig);
    }

    function deployFlowImplementation() internal returns (address) {
        return address(new Flow());
    }

    function deployFlow() internal returns (IFlowV6, EvaluableV4 memory) {
        address[] memory expressions = new address[](1);
        expressions[0] = address(uint160(uint256(keccak256("expression"))));
        (IFlowV6 flow, EvaluableV4[] memory evaluables) =
            deployFlow({expressions: expressions, constants: new uint256[](0).matrixFrom()});
        return (flow, evaluables[0]);
    }

    function deployFlow(address[] memory expressions, uint256[][] memory constants)
        internal
        returns (IFlowV6, EvaluableV4[] memory)
    {
        (address flow, EvaluableV4[] memory evaluables) = deployFlow({
            name: "",
            symbol: "",
            baseURI: "",
            expressions: expressions,
            configExpression: address(uint160(uint256(keccak256("configExpression")))),
            constants: constants
        });
        return (IFlowV6(flow), evaluables);
    }

    function mintAndBurnFlowStack(address, uint256, uint256, uint256, FlowTransferV1 memory transfer)
        internal
        pure
        returns (uint256[] memory, bytes32)
    {
        return _buildFlowStack(transfer);
    }
}
