// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when the flow being evaluated is unregistered.
/// @param unregisteredHash Hash of the unregistered flow.
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

/// Thrown when the min outputs for a flow is fewer than the sentinels. This
/// is always an implementation bug as the min outputs and sentinel count
/// should both be compile time constants.
/// @param flowMinOutputs The min outputs for the flow.
error BadMinStackLength(uint256 flowMinOutputs);
