// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    FIXED_POINT_ONE,
    FLAG_SATURATE,
    FLAG_ROUND_UP,
    FIXED_POINT_DECIMALS,
    OVERFLOW_RESCALE_OOMS
} from "./FixedPointDecimalConstants.sol";
import {ErrScaleDownPrecisionLoss, IntegerOverflow} from "../error/ErrScale.sol";

/// @title FixedPointDecimalScale
/// @notice Tools to scale unsigned values to/from 18 decimal fixed point
/// representation.
///
/// Overflows error and underflows are rounded up or down explicitly.
///
/// The max uint256 as decimal is roughly 1e77 so scaling values comparable to
/// 1e18 is unlikely to ever overflow in most contexts. For a typical use case
/// involving tokens, the entire supply of a token rescaled up a full 18 decimals
/// would still put it "only" in the region of ~1e40 which has a full 30 orders
/// of magnitude buffer before running into saturation issues. However, there's
/// no theoretical reason that a token or any other use case couldn't use large
/// numbers or extremely precise decimals that would push this library to
/// overflow point, so it MUST be treated with caution around the edge cases.
///
/// Scaling down ANY fixed point decimal also reduces the precision which can
/// lead to  dust or in the worst case trapped funds if subsequent subtraction
/// overflows a rounded-down number. Consider using saturating subtraction for
/// safety against previously downscaled values, and whether trapped dust is a
/// significant issue. If you need to retain full/arbitrary precision in the case
/// of downscaling DO NOT use this library.
///
/// All rescaling and/or division operations in this library require a rounding
/// flag. This allows and forces the caller to specify where dust sits due to
/// rounding. For example the caller could round up when taking tokens from
/// `msg.sender` and round down when returning them, ensuring that any dust in
/// the round trip accumulates in the contract rather than opening an exploit or
/// reverting and trapping all funds. This is exactly how the ERC4626 vault spec
/// handles dust and is a good reference point in general. Typically the contract
/// holding tokens and non-interactive participants should be favoured by
/// rounding calculations rather than active participants. This is because we
/// assume that an active participant, e.g. `msg.sender`, knowns something we
/// don't and is carefully crafting an attack, so we are most conservative and
/// suspicious of their inputs and actions.
library LibFixedPointDecimalScale {
    /// Scales `a` up by a specified number of decimals.
    /// @param a The number to scale up.
    /// @param scaleUpBy Number of orders of magnitude to scale `b_` up by.
    /// Errors if overflows.
    /// @return b `a` scaled up by `scaleUpBy`.
    function scaleUp(uint256 a, uint256 scaleUpBy) internal pure returns (uint256 b) {
        // Checked power is expensive so don't do that.
        unchecked {
            b = 10 ** scaleUpBy;
        }
        b = a * b;

        // We know exactly when 10 ** X overflows so replay the checked version
        // to get the standard Solidity overflow behaviour. The branching logic
        // here is still ~230 gas cheaper than unconditionally running the
        // overflow checks. We're optimising for standardisation rather than gas
        // in the unhappy revert case.
        if (scaleUpBy >= OVERFLOW_RESCALE_OOMS) {
            b = a == 0 ? 0 : 10 ** scaleUpBy;
        }
    }

    /// Identical to `scaleUp` but saturates instead of reverting on overflow.
    /// @param a As per `scaleUp`.
    /// @param scaleUpBy As per `scaleUp`.
    /// @return c As per `scaleUp` but saturates as `type(uint256).max` on
    /// overflow.
    function scaleUpSaturating(uint256 a, uint256 scaleUpBy) internal pure returns (uint256 c) {
        unchecked {
            if (scaleUpBy >= OVERFLOW_RESCALE_OOMS) {
                c = a == 0 ? 0 : type(uint256).max;
            } else {
                // Adapted from saturatingMath.
                // Inlining everything here saves ~250-300+ gas relative to slow.
                uint256 b_ = 10 ** scaleUpBy;
                c = a * b_;
                // Checking b_ here allows us to skip an "is zero" check because even
                // 10 ** 0 = 1, so we have a positive lower bound on b_.
                c = c / b_ == a ? c : type(uint256).max;
            }
        }
    }

    /// Scales `a` down by a specified number of decimals, rounding down.
    /// Used internally by several other functions in this lib.
    /// @param a The number to scale down.
    /// @param scaleDownBy Number of orders of magnitude to scale `a` down by.
    /// Overflows if greater than 77.
    /// @return c `a` scaled down by `scaleDownBy` and rounded down.
    function scaleDown(uint256 a, uint256 scaleDownBy) internal pure returns (uint256) {
        unchecked {
            return scaleDownBy >= OVERFLOW_RESCALE_OOMS ? 0 : a / (10 ** scaleDownBy);
        }
    }

    /// Scales `a` down by a specified number of decimals, rounding up.
    /// Used internally by several other functions in this lib.
    /// @param a The number to scale down.
    /// @param scaleDownBy Number of orders of magnitude to scale `a` down by.
    /// Overflows if greater than 77.
    /// @return c `a` scaled down by `scaleDownBy` and rounded up.
    function scaleDownRoundUp(uint256 a, uint256 scaleDownBy) internal pure returns (uint256 c) {
        unchecked {
            if (scaleDownBy >= OVERFLOW_RESCALE_OOMS) {
                c = a == 0 ? 0 : 1;
            } else {
                uint256 b = 10 ** scaleDownBy;
                c = a / b;

                // Intentionally doing a divide before multiply here to detect
                // the need to round up.
                //slither-disable-next-line divide-before-multiply
                if (a != c * b) {
                    c += 1;
                }
            }
        }
    }

    /// Scale a fixed point decimal of some scale factor to 18 decimals.
    /// @param a Some fixed point decimal value.
    /// @param decimals The number of fixed decimals of `a`.
    /// @param flags Controls rounding and saturation.
    /// @return `a` scaled to 18 decimals.
    function scale18(uint256 a, uint256 decimals, uint256 flags) internal pure returns (uint256) {
        unchecked {
            if (FIXED_POINT_DECIMALS > decimals) {
                uint256 scaleUpBy = FIXED_POINT_DECIMALS - decimals;
                if (flags & FLAG_SATURATE > 0) {
                    return scaleUpSaturating(a, scaleUpBy);
                } else {
                    return scaleUp(a, scaleUpBy);
                }
            } else if (decimals > FIXED_POINT_DECIMALS) {
                uint256 scaleDownBy = decimals - FIXED_POINT_DECIMALS;
                if (flags & FLAG_ROUND_UP > 0) {
                    return scaleDownRoundUp(a, scaleDownBy);
                } else {
                    return scaleDown(a, scaleDownBy);
                }
            } else {
                return a;
            }
        }
    }

    /// Scale an 18 decimal fixed point value to some other scale.
    /// Exactly the inverse behaviour of `scale18`. Where `scale18` would scale
    /// up, `scaleN` scales down, and vice versa.
    /// @param a An 18 decimal fixed point number.
    /// @param targetDecimals The new scale of `a`.
    /// @param flags Controls rounding and saturation.
    /// @return `a` rescaled from 18 to `targetDecimals`.
    function scaleN(uint256 a, uint256 targetDecimals, uint256 flags) internal pure returns (uint256) {
        unchecked {
            if (FIXED_POINT_DECIMALS > targetDecimals) {
                uint256 scaleDownBy = FIXED_POINT_DECIMALS - targetDecimals;
                if (flags & FLAG_ROUND_UP > 0) {
                    return scaleDownRoundUp(a, scaleDownBy);
                } else {
                    return scaleDown(a, scaleDownBy);
                }
            } else if (targetDecimals > FIXED_POINT_DECIMALS) {
                uint256 scaleUpBy = targetDecimals - FIXED_POINT_DECIMALS;
                if (flags & FLAG_SATURATE > 0) {
                    return scaleUpSaturating(a, scaleUpBy);
                } else {
                    return scaleUp(a, scaleUpBy);
                }
            } else {
                return a;
            }
        }
    }

    /// Scale a fixed point up or down by `ooms` orders of magnitude.
    /// Notably `scaleBy` is a SIGNED integer so scaling down by negative OOMS
    /// IS supported.
    /// @param a Some integer of any scale.
    /// @param ooms OOMs to scale `a` up or down by. This is a SIGNED int8
    /// which means it can be negative, and also means that sign extension MUST
    /// be considered if changing it to another type.
    /// @param flags Controls rounding and saturating.
    /// @return `a` rescaled according to `ooms`.
    function scaleBy(uint256 a, int8 ooms, uint256 flags) internal pure returns (uint256) {
        unchecked {
            if (ooms > 0) {
                if (flags & FLAG_SATURATE > 0) {
                    // Positive ooms fits in unsigned space.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    return scaleUpSaturating(a, uint8(ooms));
                } else {
                    // Positive ooms fits in unsigned space.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    return scaleUp(a, uint8(ooms));
                }
            } else if (ooms < 0) {
                // We know that ooms is negative here, so we can convert it
                // to an absolute value with bitwise NOT + 1.
                // This is slightly less gas than multiplying by negative 1 and
                // casting it, and handles the case of -128 without overflow.
                //forge-lint: disable-next-line(unsafe-typecast)
                uint8 scaleDownBy = uint8(~ooms) + 1;
                if (flags & FLAG_ROUND_UP > 0) {
                    return scaleDownRoundUp(a, scaleDownBy);
                } else {
                    return scaleDown(a, scaleDownBy);
                }
            } else {
                return a;
            }
        }
    }

    /// Scale an 18 decimal fixed point number to scale 0 (i.e. an integer)
    /// losslessly.
    /// Reverts if the conversion would be lossy.
    /// @param a An 18 decimal fixed point number.
    /// @return `a` scaled to 0 decimals.
    function scaleToIntegerLossless(uint256 a) internal pure returns (uint256) {
        unchecked {
            if (a % FIXED_POINT_ONE != 0) {
                revert ErrScaleDownPrecisionLoss(a);
            }
            return a / FIXED_POINT_ONE;
        }
    }

    /// Detect whether some value is a fixed point decimal or an integer and
    /// convert it to an integer if it is a decimal.
    ///
    /// The detection process assumes that anything greater than or equal to
    /// `FIXED_POINT_ONE` is a fixed point decimal and NOT some large integer.
    ///
    /// The caller is responsible for ensuring that the range of valid integers
    /// never overlaps with the range of valid fixed point decimals that could
    /// be interpreted as integers. I.e. `max` should be less than `1e18`.
    ///
    /// Uses lossless conversion to integer for fixed point decimals, so will
    /// error if decimals are not a multiple of `FIXED_POINT_ONE`.
    ///
    /// @param a The value to convert to an integer.
    /// @param max The maximum value that `a` can be. MUST be less than `1e18`.
    function decimalOrIntToInt(uint256 a, uint256 max) internal pure returns (uint256) {
        if (a >= FIXED_POINT_ONE) {
            a = scaleToIntegerLossless(a);
        }

        if (a > max) {
            revert IntegerOverflow(a, max);
        }

        return a;
    }
}
