// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";
import {FlowTransferOperation} from "test/abstract/FlowTransferOperation.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {FlowTransferV1, IFlowV5, RAIN_FLOW_SENTINEL, Sentinel} from "../../src/interface/IFlowV5.sol";
import {Flow} from "../../src/concrete/Flow.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";

abstract contract FlowTest is FlowTransferOperation, InterpreterMockTest {
    using LibLogHelper for Vm.Log[];
    using LibStackGeneration for uint256;
    using Address for address;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];

    CloneFactory internal immutable I_CLONE_FACTORY;

    constructor() {
        vm.pauseGasMetering();
        I_CLONE_FACTORY = new CloneFactory();
        vm.resumeGasMetering();
    }

    function expressionDeployer(address expression, uint256[] memory constants, bytes memory bytecode)
        internal
        returns (EvaluableConfigV3 memory)
    {
        expressionDeployerDeployExpression2MockCall(bytecode, constants, expression, bytes(hex"00060001"));
        return EvaluableConfigV3(DEPLOYER, bytecode, constants);
    }

    function expressionDeployer(uint256 key, address expression, uint256[] memory constants)
        internal
        returns (EvaluableConfigV3 memory)
    {
        return expressionDeployer(expression, constants, abi.encodePacked(vm.addr(key)));
    }

    function deployFlow(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address[] memory expressions,
        address configExpression,
        uint256[][] memory constants
    ) internal returns (address flow, EvaluableV2[] memory evaluables) {
        require(expressions.length == constants.length, "Expressions and constants array lengths must match");

        {
            EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](expressions.length);

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
            logs = logs.findEvents(keccak256("FlowInitialized(address,(address,address,address))"));
            evaluables = new EvaluableV2[](logs.length);
            for (uint256 i = 0; i < logs.length; i++) {
                (, EvaluableV2 memory evaluable) = abi.decode(logs[i].data, (address, EvaluableV2));
                evaluables[i] = evaluable;
            }
        }
    }

    function createMockBytecode() internal pure virtual returns (bytes memory) {
        /*
            Bytecode structure:
            - First byte: 0x03 (sourceCount = 3)
            - Next 2 bytes: 0x0002 (offset for sourceIndex = 0)
            - Next 2 bytes: 0x0005 (offset for sourceIndex = 1)
            - Next 2 bytes: 0x0008 (offset for sourceIndex = 2)
            - Data for sourceIndex = 0:
                - opsCount: 0x0A
                - opcode: 0xAA
            - Data for sourceIndex = 1:
                - opsCount: 0x0B
                - opcode: 0xBB
            - Data for sourceIndex = 2:
                - opsCount: 0x0C
                - opcode: 0xCC
        */
        return hex"030002000500080AAA0BBB0CCC";
    }

    function assumeEtchable(address account) internal view {
        assumeEtchable(account, address(0));
    }

    function assumeEtchable(address account, address expression) internal view {
        assumeNotPrecompile(account);
        vm.assume(account != address(DEPLOYER));
        vm.assume(account != address(INTERPRETER));
        vm.assume(account != address(STORE));
        vm.assume(account != address(I_CLONE_FACTORY));
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != uint256(uint160(account)));
        vm.assume(account != address(expression));
        vm.assume(!account.isContract());
        // The console.
        vm.assume(account != address(0x000000000000000000636F6e736F6c652e6c6f67));
    }

    function burnFlowStack(address, uint256, uint256, FlowTransferV1 memory transfer)
        internal
        pure
        returns (uint256[] memory, bytes32)
    {
        bytes32 transferHash = keccak256(abi.encode(transfer));
        uint256[] memory stack = Sentinel.unwrap(RAIN_FLOW_SENTINEL).generateFlowStack(transfer);
        return (stack, transferHash);
    }

    function mintFlowStack(address, uint256, uint256, FlowTransferV1 memory transfer)
        internal
        pure
        returns (uint256[] memory, bytes32)
    {
        bytes32 transferHash = keccak256(abi.encode(transfer));
        uint256[] memory stack = Sentinel.unwrap(RAIN_FLOW_SENTINEL).generateFlowStack(transfer);
        return (stack, transferHash);
    }

    function buildConfig(string memory, string memory, string memory, address, EvaluableConfigV3[] memory flowConfig)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(flowConfig);
    }

    function deployFlowImplementation() internal returns (address) {
        return address(new Flow());
    }

    function deployFlow() internal returns (IFlowV5, EvaluableV2 memory) {
        address[] memory expressions = new address[](1);
        expressions[0] = address(uint160(uint256(keccak256("expression"))));
        (IFlowV5 flow, EvaluableV2[] memory evaluables) =
            deployFlow({expressions: expressions, constants: new uint256[](0).matrixFrom()});
        return (flow, evaluables[0]);
    }

    function deployFlow(address[] memory expressions, uint256[][] memory constants)
        internal
        returns (IFlowV5, EvaluableV2[] memory)
    {
        (address flow, EvaluableV2[] memory evaluables) = deployFlow({
            name: "",
            symbol: "",
            baseURI: "",
            expressions: expressions,
            configExpression: address(uint160(uint256(keccak256("configExpression")))),
            constants: constants
        });
        return (IFlowV5(flow), evaluables);
    }

    function mintAndBurnFlowStack(address, uint256, uint256, uint256, FlowTransferV1 memory transfer)
        internal
        pure
        returns (uint256[] memory, bytes32)
    {
        bytes32 transferHash = keccak256(abi.encode(transfer));
        uint256[] memory stack = Sentinel.unwrap(RAIN_FLOW_SENTINEL).generateFlowStack(transfer);
        return (stack, transferHash);
    }
}
