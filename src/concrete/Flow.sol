// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {
    IInterpreterCallerV4,
    SignedContextV1,
    EvaluableV4
} from "rain.interpreter.interface/interface/IInterpreterCallerV4.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {UnregisteredFlow} from "../interface/IFlowV6.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {
    IInterpreterV4,
    EvalV4,
    StackItem,
    SourceIndexV2,
    DEFAULT_STATE_NAMESPACE
} from "rain.interpreter.interface/interface/IInterpreterV4.sol";
import {IInterpreterStoreV3} from "rain.interpreter.interface/interface/IInterpreterStoreV3.sol";
import {
    MulticallUpgradeable as Multicall
} from "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {ERC721Holder} from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {LibBytes32Matrix} from "rain.solmem/lib/LibBytes32Matrix.sol";
import {LibNamespace, StateNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {EmptyFlowConfig, BadMinStackLength} from "../error/ErrFlow.sol";
import {IFlowV6, MIN_FLOW_SENTINELS, FlowTransferV1} from "../interface/IFlowV6.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {LibFlow} from "../lib/LibFlow.sol";

/// @dev The entrypoint for a flow is always `0` because each flow has its own
/// evaluable with its own entrypoint. Running multiple flows involves evaluating
/// several expressions in sequence.
SourceIndexV2 constant FLOW_ENTRYPOINT = SourceIndexV2.wrap(0);
/// @dev There is no maximum number of outputs for a flow. Pragmatically gas will
/// limit the number of outputs well before this limit is reached.
uint16 constant FLOW_MAX_OUTPUTS = type(uint16).max;

/// @dev Any non-zero value indicates that the flow is registered.
uint256 constant FLOW_IS_REGISTERED = 1;

/// @dev Zero indicates that the flow is not registered.
uint256 constant FLOW_IS_NOT_REGISTERED = 0;

/// @title Flow
/// @notice The concrete `IFlowV6` implementation. Handles evaluable
/// registration at init time, dispatches `flow` calls against registered
/// evaluables, and implements the `stackToFlow` preview entrypoint
/// directly. Also satisfies the receiver interfaces needed to hold ERC721
/// and ERC1155 tokens.
///
/// `Flow` is deployed as a reference implementation and cloned via a
/// factory; the constructor disables initializers so the implementation
/// itself is unusable. Every clone is initialized with its own set of
/// evaluables, giving per-clone isolation: a clone can only
/// evaluate flows it was registered with, and individual clones cannot
/// collide state with each other given a correctly implemented
/// interpreter store. Clone deployments cost well under 1M gas, so the
/// pattern scales horizontally — many cheap bespoke flow contracts
/// rather than one monolithic protocol.
///
/// `Flow` inherits `Multicall` and is therefore NOT compatible with
/// receiving ETH. `Multicall` uses `delegatecall` in a loop which reuses
/// `msg.value` for each iteration, "double-spending" any ETH received.
/// Native flows were removed in V2 for this reason; reintroducing them
/// would require replacing the batching primitive (samczsun, "two
/// rights might make a wrong").
contract Flow is ERC721Holder, ERC1155Holder, Multicall, ReentrancyGuard, IInterpreterCallerV4, ICloneableV2, IFlowV6 {
    using LibUint256Array for uint256[];
    using LibBytes32Matrix for bytes32[];
    using LibEvaluable for EvaluableV4;
    using LibNamespace for StateNamespace;

    /// @dev This mapping tracks all flows that are registered at initialization.
    /// This is used to ensure that only registered flows are evaluated.
    /// Inheriting contracts MUST check this mapping before evaluating a flow,
    /// else anons can deploy their own evaluable and drain the contract.
    /// `isRegistered` will be set to `FLOW_IS_REGISTERED` for each registered
    /// flow.
    mapping(bytes32 evaluableHash => uint256 isRegistered) internal registeredFlows;

    /// This event is emitted when a flow is registered at initialization.
    /// @param sender The address that registered the flow.
    /// @param evaluable The evaluable of the flow that was registered. The hash
    /// of this evaluable is used as the key in `registeredFlows` so users MUST
    /// provide the same evaluable when they evaluate the flow.
    event FlowInitialized(address sender, EvaluableV4 evaluable);

    /// Disables initializers on the implementation contract so that any
    /// usable instance is a proxy / clone that runs `initialize` exactly
    /// once. Forcing this through a factory encourages the
    /// atomically-clone-then-initialize pattern; a directly-deployed
    /// implementation is unusable.
    constructor() {
        _disableInitializers();
    }

    /// The typed `initialize(EvaluableV4[])` overload exists only to
    /// surface the parameter shape in the ABI for tooling. It MUST always
    /// revert with `InitializeSignatureFn` per the `ICloneableV2`
    /// contract; the canonical entrypoint is `initialize(bytes)`. The
    /// parameter is unnamed because the function reverts before reading it.
    function initialize(EvaluableV4[] memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        EvaluableV4[] memory flowConfig = abi.decode(data, (EvaluableV4[]));
        emit Initialize(msg.sender, flowConfig);

        flowInit(flowConfig, MIN_FLOW_SENTINELS);
        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IFlowV6
    function stackToFlow(StackItem[] memory stack) external pure virtual override returns (FlowTransferV1 memory) {
        uint256[] memory stackU;
        assembly ("memory-safe") {
            stackU := stack
        }
        return LibFlow.stackToFlow(stackU.dataPointer(), stackU.endPointer());
    }

    /// @inheritdoc IFlowV6
    function flow(EvaluableV4 memory evaluable, bytes32[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        nonReentrant
        returns (FlowTransferV1 memory)
    {
        (Pointer stackBottom, Pointer stackTop, bytes32[] memory kvs) =
            _flowStack(evaluable, callerContext, signedContexts);
        FlowTransferV1 memory flowTransfer = LibFlow.stackToFlow(stackBottom, stackTop);
        LibFlow.flow(flowTransfer, evaluable.store, kvs);
        return flowTransfer;
    }

    /// Common initialization logic for inheriting contracts. This MUST be
    /// called by inheriting contracts in their initialization logic (and only).
    /// @param evaluables The evaluable configs to register at
    /// initialization. Each of these represents a flow that defines valid token
    /// movements at runtime for the inheriting contract.
    /// @param flowMinOutputs The minimum number of outputs for each flow. All
    /// flows share the same minimum number of outputs for simplicity.
    function flowInit(EvaluableV4[] memory evaluables, uint256 flowMinOutputs) internal onlyInitializing {
        unchecked {
            // First dispatch all the Open Zeppelin initializers.
            __Multicall_init();

            // Reject empty configs at init time — an empty config would
            // produce a permanently inert clone where every `flow()` call
            // reverts with `UnregisteredFlow`.
            if (evaluables.length == 0) {
                revert EmptyFlowConfig();
            }

            // This should never fail because the min outputs should always be
            // at least the number of sentinels, and is compile time constant.
            // It's a cheap sanity check on the downstream implementation.
            if (flowMinOutputs < MIN_FLOW_SENTINELS) {
                revert BadMinStackLength(flowMinOutputs);
            }

            EvaluableV4 memory evaluable;
            // In V4 the caller provides already-compiled evaluables
            // (interpreter, store, bytecode) directly; there is no deploy-time
            // integrity check. Flow validity is enforced at eval time by
            // sentinel consumption against MIN_FLOW_SENTINELS, matching the
            // upstream RaindexV6 caller model.
            for (uint256 i = 0; i < evaluables.length; ++i) {
                evaluable = evaluables[i];
                // There's no way to set this mapping before the external
                // contract call because the output of the external contract
                // call is used to build the evaluable that we're registering.
                // Even if we could modify state before making external calls,
                // it probably wouldn't make sense to be finalisating the
                // registration of a flow before we know that the flow is
                // deployable according to the deployer's own integrity checks.
                //slither-disable-next-line reentrancy-benign
                registeredFlows[evaluable.hash()] = FLOW_IS_REGISTERED;
                // There's no way to emit this event before the external contract
                // call because the output of the external contract call is
                // the input to the event.
                //slither-disable-next-line reentrancy-events
                emit FlowInitialized(msg.sender, evaluable);
            }
        }
    }

    /// Standard evaluation logic for flows. This includes critical guards to
    /// ensure that only registered flows are evaluated. This is the only
    /// function that inheriting contracts should call to evaluate flows.
    /// The start and end pointers to the stack are returned so that inheriting
    /// contracts can easily scan the stack for sentinels, which is the expected
    /// pattern to determine what token moments are required.
    /// @param evaluable The evaluable to evaluate.
    /// @param callerContext The caller context to evaluate the evaluable with.
    /// @param signedContexts The signed contexts to evaluate the evaluable with.
    /// @return The bottom of the stack after evaluation.
    /// @return The top of the stack after evaluation.
    /// @return The key-value pairs that were emitted during evaluation.
    function _flowStack(
        EvaluableV4 memory evaluable,
        bytes32[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) internal returns (Pointer, Pointer, bytes32[] memory) {
        bytes32[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
        emit ContextV2(msg.sender, context);

        // Refuse to evaluate unregistered flows.
        {
            bytes32 evaluableHash = evaluable.hash();
            if (registeredFlows[evaluableHash] == FLOW_IS_NOT_REGISTERED) {
                revert UnregisteredFlow(evaluableHash);
            }
        }

        (StackItem[] memory stack, bytes32[] memory kvs) = evaluable.interpreter
            .eval4(
                EvalV4({
                    store: evaluable.store,
                    namespace: DEFAULT_STATE_NAMESPACE.qualifyNamespace(address(this)),
                    bytecode: evaluable.bytecode,
                    sourceIndex: FLOW_ENTRYPOINT,
                    context: context,
                    inputs: new StackItem[](0),
                    stateOverlay: new bytes32[](0)
                })
            );
        uint256[] memory stackU;
        assembly ("memory-safe") {
            stackU := stack
        }
        return (stackU.dataPointer(), stackU.endPointer(), kvs);
    }
}
