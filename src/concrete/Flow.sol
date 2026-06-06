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
import {EmptyFlowConfig} from "../error/ErrFlow.sol";
import {IFlowV6, MIN_FLOW_SENTINELS, FlowTransferV1} from "../interface/IFlowV6.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {LibFlow} from "../lib/LibFlow.sol";

/// Thrown when the min outputs for a flow is fewer than the sentinels.
/// This is always an implementation bug as the min outputs and sentinel count
/// should both be compile time constants.
/// @param flowMinOutputs The min outputs for the flow.
error BadMinStackLength(uint256 flowMinOutputs);

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
/// @notice Common functionality for flows. Largely handles the evaluable
/// registration and dispatch. Also implementes the necessary interfaces for
/// a smart contract to receive ERC721 and ERC1155 tokens.
///
/// Flow contracts are expected to be deployed via. a proxy/factory as clones
/// of an implementation contract. This makes flows cheap to deploy and every
/// flow contract can be initialized with a different set of flows. This gives
/// strong guarantees that the flow contract is only capable of evaluating
/// registered flows, and that individual flow contracts cannot collide state
/// with each other, given a correctly implemented interpreter store. Combining
/// proxies with rainlang gives us a very powerful and flexible system for
/// composing flows without significant gas overhead. Typically a flow contract
/// deployment will cost well under 1M gas, which is very cheap for bespoke
/// logic, without significant runtime overheads. This allows for new UX patterns
/// where users can cheaply create many different tools such as NFT mints,
/// auctions, escrows, etc. and aim to horizontally scale rather than design
/// monolithic protocols.
///
/// This does NOT implement the preview and flow logic directly because each
/// flow implementation has different requirements for the mint and burn logic
/// of the flow tokens. In the future, this may be refactored so that a single
/// flow contract can handle all flows.
///
/// `Flow` is `Multicall` so it is NOT compatible with receiving ETH. This
/// is because `Multicall` uses `delegatecall` in a loop which reuses `msg.value`
/// for each loop iteration, effectively "double spending" the ETH it receives.
/// This is a known issue with `Multicall` so in the future, we may refactor
/// `Flow` to not use `Multicall` and instead implement flow batching
/// directly in the flow contracts.
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

    /// Forwards config to `DeployerDiscoverableMetaV2` and disables
    /// initializers. The initializers are disabled because inheriting contracts
    /// are expected to implement some kind of initialization logic that is
    /// compatible with cloning via. proxy/factory. Disabling initializers
    /// in the implementation contract forces that the only way to initialize
    /// the contract is via. a proxy, which should also strongly encourage
    /// patterns that _atomically_ clone and initialize via. some factory.
    constructor() {
        _disableInitializers();
    }

    /// Overloaded typed initialize function MUST revert with this error.
    /// As per `ICloneableV2` interface.
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

    /// @inheritdoc IFlowV5
    function stackToFlow(StackItem[] memory stack) external pure virtual override returns (FlowTransferV1 memory) {
        uint256[] memory stackU;
        assembly ("memory-safe") {
            stackU := stack
        }
        return LibFlow.stackToFlow(stackU.dataPointer(), stackU.endPointer());
    }

    /// @inheritdoc IFlowV5
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
    /// @param evaluableConfigs The evaluable configs to register at
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

        (StackItem[] memory stack, bytes32[] memory kvs) = evaluable.interpreter.eval4(
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
