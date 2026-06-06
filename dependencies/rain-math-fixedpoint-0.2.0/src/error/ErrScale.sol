// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @dev Thrown when downscaling would result in precision loss in a lossless
/// conversion.
/// @param a The value that would lose precision.
error ErrScaleDownPrecisionLoss(uint256 a);

/// Thrown when an integer is too large to fit in the range allowed for it.
/// @param integer The integer that is too large.
/// @param max The maximum value that the integer can be.
error IntegerOverflow(uint256 integer, uint256 max);
