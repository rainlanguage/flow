// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when the flow being evaluated is unregistered.
/// @param unregisteredHash Hash of the unregistered flow.
error UnregisteredFlow(bytes32 unregisteredHash);

/// Thrown for unsupported native transfers.
error UnsupportedNativeFlow();

/// Thrown for unsupported erc20 transfers.
error UnsupportedERC20Flow();

/// Thrown for unsupported erc721 transfers.
error UnsupportedERC721Flow();

/// Thrown for unsupported erc1155 transfers.
error UnsupportedERC1155Flow();

contract ErrFLow {}

/// Thrown when burner of tokens is not the owner of tokens.
error BurnerNotOwner();

error UnsupportedHandleTransferInputs();
error InsufficientHandleTransferOutputs();
error UnsupportedTokenURIInputs();
error InsufficientTokenURIOutputs();
error UnsupportedFlowInputs();
error InsufficientFlowOutputs();
