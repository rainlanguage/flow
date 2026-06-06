// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {FIXED_POINT_ONE} from "../FixedPointDecimalConstants.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";

library LibFixedPointDecimalFormat {
    /// @notice Convert a fixed point decimal to a string representation.
    /// Trailing zeros are removed and decimals are only included if the value is
    /// non-integer as fixed point decimals.
    /// e.g. `1e18` -> "1", `1.1e18` -> "1.1", `0.1e18` -> "0.1"
    /// @param value The fixed point decimal to convert.
    function fixedPointToDecimalString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 integral = value / FIXED_POINT_ONE;
            uint256 frac = value % FIXED_POINT_ONE;

            string memory integralString = Strings.toString(integral);

            if (frac == 0) {
                return integralString;
            }

            // Can't overflow because frac is less than FIXED_POINT_ONE.
            uint256 fracPlusOne = frac + FIXED_POINT_ONE;

            // Stringifying fracPlusOne preserves the leading zeros in our frac
            // as a string decimal, but also introduces trailing zeros. We need
            // to slice out the leading "1" digit and trailing zeros manually.
            string memory fracString = Strings.toString(fracPlusOne);

            uint256 trailingZeros = 0;
            uint256 divisor = 10;
            // Divide first to try to discover imprecision due to a suspected
            // trailing zero being non-zero. Also means we cannot overflow.
            //slither-disable-start divide-before-multiply
            //forge-lint: disable-next-line(divide-before-multiply)
            while (fracPlusOne == (fracPlusOne / divisor) * divisor) {
                trailingZeros += 1;
                divisor *= 10;
            }
            //slither-disable-end

            assembly ("memory-safe") {
                // This can't underflow because we're always guaranteed at least
                // one non-zero digit in fracString due to the +FIXED_POINT_ONE.
                // If it underflows that implies we miscalculated trailingZeros.
                let newLength := sub(mload(fracString), add(1, trailingZeros))
                // We can write newlength directly over the old length and
                // leading "1" digit in fracString. This saves us having to
                // allocate and copy memory.
                fracString := add(fracString, 1)
                mstore(fracString, newLength)
            }

            return string(abi.encodePacked(integralString, ".", fracString));
        }
    }
}
