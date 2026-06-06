// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/deprecated/v2/IInterpreterStoreV2.sol";
import {
    IInterpreterV2,
    EncodedDispatch,
    DEFAULT_STATE_NAMESPACE
} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/deprecated/v1/IExpressionDeployerV3.sol";
import {LibNamespace, StateNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";

abstract contract InterpreterMockTest is Test {
    using LibNamespace for StateNamespace;

    IInterpreterV2 constant INTERPRETER = IInterpreterV2(address(uint160(uint256(keccak256("interpreter.rain.test")))));
    IInterpreterStoreV2 constant STORE = IInterpreterStoreV2(address(uint160(uint256(keccak256("store.rain.test")))));
    IExpressionDeployerV3 constant DEPLOYER =
        IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.rain.test")))));

    constructor() {
        vm.pauseGasMetering();
        vm.etch(address(INTERPRETER), REVERTING_MOCK_BYTECODE);
        vm.etch(address(STORE), REVERTING_MOCK_BYTECODE);
        vm.etch(address(DEPLOYER), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function interpreterEval2MockCall(uint256[] memory stack, uint256[] memory writes) internal {
        vm.mockCall(
            address(INTERPRETER), abi.encodeWithSelector(IInterpreterV2.eval2.selector), abi.encode(stack, writes)
        );
    }

    function interpreterEval2MockCall(
        address nameSpaceSender,
        EncodedDispatch dispatch,
        uint256[] memory stack,
        uint256[] memory writes
    ) internal {
        vm.mockCall(
            address(INTERPRETER),
            abi.encodeWithSelector(
                IInterpreterV2.eval2.selector,
                STORE,
                DEFAULT_STATE_NAMESPACE.qualifyNamespace(nameSpaceSender),
                dispatch
            ),
            abi.encode(stack, writes)
        );
    }

    function interpreterEval2ExpectCall(address nameSpaceSender, EncodedDispatch dispatch, uint256[][] memory context)
        internal
    {
        vm.expectCall(
            address(INTERPRETER),
            abi.encodeWithSelector(
                IInterpreterV2.eval2.selector,
                STORE,
                DEFAULT_STATE_NAMESPACE.qualifyNamespace(nameSpaceSender),
                dispatch,
                context,
                new uint256[](0)
            )
        );
    }

    function interpreterEval2RevertCall(address nameSpaceSender, EncodedDispatch dispatch, uint256[][] memory context)
        internal
    {
        vm.mockCallRevert(
            address(INTERPRETER),
            abi.encodeWithSelector(
                IInterpreterV2.eval2.selector,
                STORE,
                DEFAULT_STATE_NAMESPACE.qualifyNamespace(nameSpaceSender),
                dispatch,
                context,
                new uint256[](0)
            ),
            "REVERT_EVAL2_CALL"
        );
    }

    function expressionDeployerDeployExpression2MockCall(address expression, bytes memory io) internal {
        vm.mockCall(
            address(DEPLOYER),
            abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector),
            abi.encode(INTERPRETER, STORE, expression, io)
        );
    }

    function expressionDeployerDeployExpression2MockCall(
        bytes memory bytecode,
        uint256[] memory constants,
        address expression,
        bytes memory io
    ) internal {
        vm.mockCall(
            address(DEPLOYER),
            abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector, bytecode, constants),
            abi.encode(INTERPRETER, STORE, expression, io)
        );
    }
}
