// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    FLAG_SATURATE,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    FLAG_MAX_INT,

    // Exported for convenience.
    //forge-lint: disable-next-line(unused-import)
    FLAG_ROUND_UP,
    OVERFLOW_RESCALE_OOMS,
    FIXED_POINT_DECIMALS
} from "./FixedPointDecimalConstants.sol";

/// @title LibWillOverflow
/// @notice Often we want to know if some calculation is expected to overflow.
/// Notably this is important for fuzzing as we have to be able to set
/// expectations for arbitrary inputs over as broad a range of values as
/// possible.
library LibWillOverflow {
    /// Relevant logic taken direct from Open Zeppelin.
    /// @param x As per Open Zeppelin.
    /// @param y As per Open Zeppelin.
    /// @param denominator As per Open Zeppelin.
    /// @return True if mulDiv will overflow.
    function mulDivWillOverflow(uint256 x, uint256 y, uint256 denominator) internal pure returns (bool) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly ("memory-safe") {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
        return !(denominator > prod1);
    }

    /// True if `scaleUp` will overflow.
    /// @param a The number to scale up.
    /// @param scaleBy The number of orders of magnitude to scale up by.
    /// @return True if `scaleUp` will overflow.
    function scaleUpWillOverflow(uint256 a, uint256 scaleBy) internal pure returns (bool) {
        unchecked {
            if (a == 0) {
                return false;
            }
            if (scaleBy >= OVERFLOW_RESCALE_OOMS) {
                return true;
            }
            uint256 b = 10 ** scaleBy;
            uint256 c = a * b;
            return c / b != a;
        }
    }

    /// True if `scaleDown` will round.
    /// @param a The number to scale down.
    /// @param scaleDownBy The number of orders of magnitude to scale down by.
    /// @return True if `scaleDown` will round.
    function scaleDownWillRound(uint256 a, uint256 scaleDownBy) internal pure returns (bool) {
        if (scaleDownBy >= OVERFLOW_RESCALE_OOMS) {
            return a != 0;
        }
        uint256 b = 10 ** scaleDownBy;
        uint256 c = a / b;
        // Discovering precision loss is the whole point of this check so the
        // thing slither is complaining about is exactly what we're measuring.
        //slither-disable-next-line divide-before-multiply
        return c * b != a;
    }

    /// True if `scale18` will overflow.
    /// @param a The number to scale.
    /// @param decimals The current number of decimals of `a`.
    /// @param flags The flags to use.
    /// @return True if `scale18` will overflow.
    function scale18WillOverflow(uint256 a, uint256 decimals, uint256 flags) internal pure returns (bool) {
        if (decimals < FIXED_POINT_DECIMALS && (FLAG_SATURATE & flags == 0)) {
            return scaleUpWillOverflow(a, FIXED_POINT_DECIMALS - decimals);
        } else {
            return false;
        }
    }

    /// True if `scaleN` will overflow.
    /// @param a The number to scale.
    /// @param decimals The current number of decimals of `a`.
    /// @param flags The flags to use.
    /// @return True if `scaleN` will overflow.
    function scaleNWillOverflow(uint256 a, uint256 decimals, uint256 flags) internal pure returns (bool) {
        if (decimals > FIXED_POINT_DECIMALS && (FLAG_SATURATE & flags == 0)) {
            return scaleUpWillOverflow(a, decimals - FIXED_POINT_DECIMALS);
        } else {
            return false;
        }
    }

    /// True if `scaleBy` will overflow.
    /// @param a The number to scale.
    /// @param scaleBy The number of orders of magnitude to scale by.
    /// @param flags The flags to use.
    /// @return True if `scaleBy` will overflow.
    function scaleByWillOverflow(uint256 a, int8 scaleBy, uint256 flags) internal pure returns (bool) {
        // If we're scaling up and not saturating check the overflow.
        if (scaleBy > 0 && (FLAG_SATURATE & flags == 0)) {
            // positive scale by fits in unsigned space.
            //forge-lint: disable-next-line(unsafe-typecast)
            return scaleUpWillOverflow(a, uint8(scaleBy));
        } else {
            return false;
        }
    }
}
