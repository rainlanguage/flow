// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {FIXED_POINT_ONE} from "../FixedPointDecimalConstants.sol";
import {ParseDecimalPrecisionLoss, ParseDecimalInvalidString} from "../../error/ErrParse.sol";
import {LibParseDecimal} from "rain-string-0.1.0/src/lib/parse/LibParseDecimal.sol";
import {CMASK_NUMERIC_0_9, CMASK_DECIMAL_POINT, CMASK_ZERO} from "rain-string-0.1.0/src/lib/parse/LibParseCMask.sol";
import {LibParseChar} from "rain-string-0.1.0/src/lib/parse/LibParseChar.sol";
import {ParseDecimalOverflow} from "rain-string-0.1.0/src/error/ErrParse.sol";

library LibFixedPointDecimalParse {
    /// Converts a decimal string to a fixed point decimal. Returns error
    /// selector if the string is not a valid fixed point decimal string. Fails
    /// on overflow and precision loss, as well as invalid characters in any
    /// position. DOES NOT support scientific notation.
    /// Caller MUST check the error selector is 0 before using the value.
    /// @param str The string to convert.
    /// @return errorSelector 0 if successful, otherwise the error selector.
    /// @return value The fixed point decimal value.
    function decimalStringTofixedPoint(string memory str) internal pure returns (bytes4, uint256) {
        unchecked {
            uint256 start;
            uint256 end;
            assembly ("memory-safe") {
                start := add(str, 0x20)
                end := add(start, mload(str))
            }
            uint256 cursor = start;

            cursor = LibParseChar.skipMask(start, end, CMASK_NUMERIC_0_9);
            (bytes4 integerErrorSelector, uint256 integer) = LibParseDecimal.unsafeDecimalStringToInt(start, cursor);
            if (integerErrorSelector != 0) {
                return (integerErrorSelector, 0);
            }

            uint256 value = integer * FIXED_POINT_ONE;
            if (value / FIXED_POINT_ONE != integer) {
                return (ParseDecimalOverflow.selector, 0);
            }

            if (cursor < end) {
                // Skip the decimal point or bail if there isn't one.
                if (LibParseChar.isMask(cursor, end, CMASK_DECIMAL_POINT) == 0) {
                    return (ParseDecimalInvalidString.selector, 0);
                }

                cursor++;
                uint256 fracStart = cursor;
                cursor = LibParseChar.skipMask(cursor, end, CMASK_NUMERIC_0_9);

                // Ensure there's no unprocessed garbage.
                if (cursor < end) {
                    return (ParseDecimalInvalidString.selector, 0);
                }

                {
                    uint256 trailingZeroCursor = cursor - 1;
                    while (
                        trailingZeroCursor >= fracStart
                            && LibParseChar.isMask(trailingZeroCursor, cursor, CMASK_ZERO) == 1
                    ) {
                        trailingZeroCursor--;
                    }
                    cursor = trailingZeroCursor + 1;
                }

                if (cursor > fracStart) {
                    (bytes4 errorSelector, uint256 frac) = LibParseDecimal.unsafeDecimalStringToInt(fracStart, cursor);
                    if (errorSelector != 0) {
                        return (errorSelector, 0);
                    }

                    uint256 digits = cursor - fracStart;

                    if (digits > 18) {
                        return (ParseDecimalPrecisionLoss.selector, 0);
                    }

                    uint256 ooms = 18 - digits;
                    uint256 scaledFrac = frac * 10 ** ooms;
                    uint256 preValue = value;
                    value += scaledFrac;
                    if (value < preValue) {
                        return (ParseDecimalOverflow.selector, 0);
                    }
                }
            }
            return (0, value);
        }
    }
}
