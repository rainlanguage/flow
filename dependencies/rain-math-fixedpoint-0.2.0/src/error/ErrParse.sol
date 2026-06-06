// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Thrown when parsing a string that has more precision than can be
/// represented in a fixed point decimal.
/// @param position The position in the string where the precision loss occurs.
error ParseDecimalPrecisionLoss(uint256 position);

/// Thrown when a string is parsed that is not a valid fixed point decimal.
/// @param position The position in the string where the error occurred.
error ParseDecimalInvalidString(uint256 position);
