// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when the flow being evaluated is unregistered.
/// @param unregisteredHash keccak256 of the `EvaluableV2` struct
/// (`interpreter`, `store`, `expression`) as produced by
/// `LibEvaluable.hash`. This is the same key used in the
/// `registeredFlows` mapping; an integrator catching this error can
/// hash any locally-known evaluable triple to identify which one was
/// rejected.
error UnregisteredFlow(bytes32 unregisteredHash);

/// Thrown for unsupported erc20 transfers.
error UnsupportedERC20Flow();

/// Thrown for unsupported erc721 transfers.
error UnsupportedERC721Flow();

/// Thrown for unsupported erc1155 transfers.
error UnsupportedERC1155Flow();

/// Thrown when a flow's `evaluable` declares any inputs.
/// `flow` evaluables are dispatched without inputs.
error UnsupportedFlowInputs();

/// Thrown when a flow's `evaluable` declares fewer outputs than the flow's
/// minimum (`MIN_FLOW_SENTINELS`).
error InsufficientFlowOutputs();

/// Thrown when a flow contract is initialized with no evaluable configs,
/// which would produce a permanently inert clone (every `flow()` call
/// would revert with `UnregisteredFlow`).
error EmptyFlowConfig();
