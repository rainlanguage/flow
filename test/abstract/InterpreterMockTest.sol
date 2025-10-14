// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {
    IInterpreterV2,
    EncodedDispatch,
    DEFAULT_STATE_NAMESPACE
} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {LibNamespace, StateNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";

abstract contract InterpreterMockTest is Test {
    using LibNamespace for StateNamespace;

    IInterpreterV2 internal immutable iInterpreter;
    IInterpreterStoreV2 internal immutable iStore;
    IExpressionDeployerV3 internal immutable iDeployer;

    constructor() {
        vm.pauseGasMetering();
        iInterpreter = IInterpreterV2(address(uint160(uint256(keccak256("interpreter.rain.test")))));
        vm.etch(address(iInterpreter), REVERTING_MOCK_BYTECODE);

        iStore = IInterpreterStoreV2(address(uint160(uint256(keccak256("store.rain.test")))));
        vm.etch(address(iStore), REVERTING_MOCK_BYTECODE);

        iDeployer = IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.rain.test")))));
        vm.etch(address(iDeployer), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function interpreterEval2MockCall(uint256[] memory stack, uint256[] memory writes) internal {
        vm.mockCall(
            address(iInterpreter), abi.encodeWithSelector(IInterpreterV2.eval2.selector), abi.encode(stack, writes)
        );
    }

    function interpreterEval2MockCall(
        address nameSpaceSender,
        EncodedDispatch dispatch,
        uint256[] memory stack,
        uint256[] memory writes
    ) internal {
        vm.mockCall(
            address(iInterpreter),
            abi.encodeWithSelector(
                IInterpreterV2.eval2.selector,
                iStore,
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
            address(iInterpreter),
            abi.encodeWithSelector(
                IInterpreterV2.eval2.selector,
                iStore,
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
            address(iInterpreter),
            abi.encodeWithSelector(
                IInterpreterV2.eval2.selector,
                iStore,
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
            address(iDeployer),
            abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector),
            abi.encode(iInterpreter, iStore, expression, io)
        );
    }

    function expressionDeployerDeployExpression2MockCall(
        bytes memory bytecode,
        uint256[] memory constants,
        address expression,
        bytes memory io
    ) internal {
        vm.mockCall(
            address(iDeployer),
            abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector, bytecode, constants),
            abi.encode(iInterpreter, iStore, expression, io)
        );
    }
}
