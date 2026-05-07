// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {IFlowV5} from "src/interface/IFlowV5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";

contract FlowTimeTest is FlowTest {
    /// `flow()` writes the eval2 `writes` array to the interpreter store
    /// under `DEFAULT_STATE_NAMESPACE`. (No time semantics — see file
    /// note above the contract.)
    function testFlowBasicWritesKvsToStore(uint256[] memory writeToStore) public {
        vm.assume(writeToStore.length != 0);

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        uint256[] memory stack = generateFlowStack(transferEmpty());

        interpreterEval2MockCall(stack, writeToStore);

        vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV2.set.selector), abi.encode());

        vm.expectCall(
            address(STORE),
            abi.encodeWithSelector(IInterpreterStoreV2.set.selector, DEFAULT_STATE_NAMESPACE, writeToStore)
        );

        flow.flow(evaluable, writeToStore, new SignedContextV1[](0));
    }
}
