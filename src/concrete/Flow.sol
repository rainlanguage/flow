// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {FlowCommon, LibContext} from "../../abstract/FlowCommon.sol";
import {IFlowV5, MIN_FLOW_SENTINELS, FlowTransferV1} from "../../interface/unstable/IFlowV5.sol";
import {LibFlow} from "../../lib/LibFlow.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1, EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

/// @title Flow
/// See `IFlowV5` docs.
contract Flow is ICloneableV2, IFlowV5, FlowCommon {
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];

    /// Overloaded typed initialize function MUST revert with this error.
    /// As per `ICloneableV2` interface.
    function initialize(EvaluableConfigV3[] memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        EvaluableConfigV3[] memory flowConfig = abi.decode(data, (EvaluableConfigV3[]));
        emit Initialize(msg.sender, flowConfig);

        flowCommonInit(flowConfig, MIN_FLOW_SENTINELS);
        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IFlowV5
    function stackToFlow(uint256[] memory stack) external pure virtual override returns (FlowTransferV1 memory) {
        return LibFlow.stackToFlow(stack.dataPointer(), stack.endPointer());
    }

    /// @inheritdoc IFlowV5
    function flow(EvaluableV2 memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        nonReentrant
        returns (FlowTransferV1 memory)
    {
        (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) =
            _flowStack(evaluable, callerContext, signedContexts);
        FlowTransferV1 memory flowTransfer = LibFlow.stackToFlow(stackBottom, stackTop);
        LibFlow.flow(flowTransfer, evaluable.store, kvs);
        return flowTransfer;
    }
}
