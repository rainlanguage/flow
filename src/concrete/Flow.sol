// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {
    IInterpreterCallerV2,
    SignedContextV1,
    EvaluableConfigV3
} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {UnregisteredFlow} from "../interface/IFlowV5.sol";
import {LibEvaluable, EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {
    SourceIndexV2,
    IInterpreterV2,
    IInterpreterStoreV2,
    DEFAULT_STATE_NAMESPACE
} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {
    MulticallUpgradeable as Multicall
} from "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {
    ERC721HolderUpgradeable as ERC721Holder
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {
    ERC1155HolderUpgradeable as ERC1155Holder
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable as ReentrancyGuard
} from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibNamespace, StateNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {UnsupportedFlowInputs, InsufficientFlowOutputs, EmptyFlowConfig, BadMinStackLength} from "../error/ErrFlow.sol";
import {IFlowV5, MIN_FLOW_SENTINELS, FlowTransferV1} from "../interface/IFlowV5.sol";
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
/// @notice The concrete `IFlowV5` implementation. Handles evaluable
/// registration at init time, dispatches `flow` calls against registered
/// evaluables, and implements the `stackToFlow` preview entrypoint
/// directly. Also satisfies the receiver interfaces needed to hold ERC721
/// and ERC1155 tokens.
///
/// `Flow` is deployed as a reference implementation and cloned via a
/// factory; the constructor disables initializers so the implementation
/// itself is unusable. Every clone is initialized with its own set of
/// evaluable configs, giving per-clone isolation: a clone can only
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
contract Flow is ERC721Holder, ERC1155Holder, Multicall, ReentrancyGuard, IInterpreterCallerV2, ICloneableV2, IFlowV5 {
    using LibUint256Array for uint256[];
    using LibUint256Matrix for uint256[];
    using LibEvaluable for EvaluableV2;
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
    event FlowInitialized(address sender, EvaluableV2 evaluable);

    /// Disables initializers on the implementation contract so that any
    /// usable instance is a proxy / clone that runs `initialize` exactly
    /// once. Forcing this through a factory encourages the
    /// atomically-clone-then-initialize pattern; a directly-deployed
    /// implementation is unusable.
    constructor() {
        _disableInitializers();
    }

    /// The typed `initialize(EvaluableConfigV3[])` overload exists only to
    /// surface the parameter shape in the ABI for tooling. It MUST always
    /// revert with `InitializeSignatureFn` per the `ICloneableV2`
    /// contract; the canonical entrypoint is `initialize(bytes)`. The
    /// parameter is unnamed because the function reverts before reading it.
    function initialize(EvaluableConfigV3[] memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        EvaluableConfigV3[] memory flowConfig = abi.decode(data, (EvaluableConfigV3[]));
        emit Initialize(msg.sender, flowConfig);

        flowInit(flowConfig, MIN_FLOW_SENTINELS);
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

    /// Common initialization logic for inheriting contracts. This MUST be
    /// called by inheriting contracts in their initialization logic (and only).
    /// @param evaluableConfigs The evaluable configs to register at
    /// initialization. Each of these represents a flow that defines valid token
    /// movements at runtime for the inheriting contract.
    /// @param flowMinOutputs The minimum number of outputs for each flow. All
    /// flows share the same minimum number of outputs for simplicity.
    function flowInit(EvaluableConfigV3[] memory evaluableConfigs, uint256 flowMinOutputs) internal onlyInitializing {
        unchecked {
            // First dispatch all the Open Zeppelin initializers.
            __ERC721Holder_init();
            __ERC1155Holder_init();
            __Multicall_init();
            __ReentrancyGuard_init();

            // Reject empty configs at init time — an empty config would
            // produce a permanently inert clone where every `flow()` call
            // reverts with `UnregisteredFlow`.
            if (evaluableConfigs.length == 0) {
                revert EmptyFlowConfig();
            }

            // This should never fail because the min outputs should always be
            // at least the number of sentinels, and is compile time constant.
            // It's a cheap sanity check on the downstream implementation.
            if (flowMinOutputs < MIN_FLOW_SENTINELS) {
                revert BadMinStackLength(flowMinOutputs);
            }

            EvaluableConfigV3 memory config;
            EvaluableV2 memory evaluable;
            // Every evaluable MUST deploy cleanly (e.g. pass integrity checks)
            // otherwise the entire initialization will fail.
            for (uint256 i = 0; i < evaluableConfigs.length; ++i) {
                config = evaluableConfigs[i];
                // Well behaved deployers SHOULD NOT be reentrant into the flow
                // contract. It is up to the EOA that is initializing this
                // flow contract to select a deployer that is trustworthy.
                // Reentrancy is just one of many ways that a malicious deployer
                // can cause problems, and it's probably the least of your
                // worries if you're using a malicious deployer.
                //slither-disable-next-line calls-loop
                (IInterpreterV2 interpreter, IInterpreterStoreV2 store, address expression, bytes memory io) =
                    config.deployer.deployExpression2(config.bytecode, config.constants);

                {
                    // `io` is a `bytes` array. The deployer encodes per-
                    // source `(inputs, outputs)` pairs as consecutive
                    // bytes, with source 0 first. Flow only uses one
                    // source (`FLOW_ENTRYPOINT == 0`), so byte 0 is
                    // `flowInputs` and byte 1 is `flowOutputs`.
                    // `add(io, 0x20)` skips the bytes-length word to
                    // land on the first data word.
                    uint256 flowInputs;
                    uint256 flowOutputs;
                    assembly ("memory-safe") {
                        let ioWord := mload(add(io, 0x20))
                        flowInputs := byte(0, ioWord)
                        flowOutputs := byte(1, ioWord)
                    }
                    if (flowInputs != 0) {
                        revert UnsupportedFlowInputs();
                    }
                    if (flowOutputs < flowMinOutputs) {
                        revert InsufficientFlowOutputs();
                    }
                }

                evaluable = EvaluableV2(interpreter, store, expression);
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
        EvaluableV2 memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) internal returns (Pointer, Pointer, uint256[] memory) {
        uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
        emit Context(msg.sender, context);

        // Refuse to evaluate unregistered flows.
        {
            bytes32 evaluableHash = evaluable.hash();
            if (registeredFlows[evaluableHash] == FLOW_IS_NOT_REGISTERED) {
                revert UnregisteredFlow(evaluableHash);
            }
        }

        (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter
            .eval2(
                evaluable.store,
                DEFAULT_STATE_NAMESPACE.qualifyNamespace(address(this)),
                LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
                context,
                new uint256[](0)
            );
        return (stack.dataPointer(), stack.endPointer(), kvs);
    }
}
