// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title LibCast
/// @notice Additional type casting logic that the Solidity compiler doesn't
/// give us by default. A type cast (vs. conversion) is considered one where the
/// structure is unchanged by the cast. The cast does NOT (can't) check that the
/// input is a valid output, for example any integer MAY be cast to a function
/// pointer but almost all integers are NOT valid function pointers. It is the
/// calling context that MUST ensure the validity of the data, the cast will
/// merely retype the data in place, generally without additional checks.
/// As most structures in solidity have the same memory structure as a `uint256`
/// or fixed/dynamic array of `uint256` there are many conversions that can be
/// done with near zero or minimal overhead.
library LibCast {
    /// Retype an array of `uint256[]` to `address[]`.
    /// @param us The array of integers to cast to addresses.
    /// @return addresses The array of addresses cast from each integer.
    function asAddressesArray(uint256[] memory us) internal pure returns (address[] memory addresses) {
        assembly ("memory-safe") {
            addresses := us
        }
    }

    /// Retype an array of `address[]` to `uint256[]`.
    /// @param addresses The array of addresses to cast to integers.
    /// @return us The array of integers cast from each address.
    function asUint256Array(address[] memory addresses) internal pure returns (uint256[] memory us) {
        assembly ("memory-safe") {
            us := addresses
        }
    }

    /// Retype an array of `uint256[]` to `bytes32[]`.
    /// @param us The array of integers to cast to 32 byte words.
    /// @return b32s The array of 32 byte words.
    function asBytes32Array(uint256[] memory us) internal pure returns (bytes32[] memory b32s) {
        assembly ("memory-safe") {
            b32s := us
        }
    }

    /// Retype an array of `bytes32[]` to `uint256[]`.
    /// @param b32s The array of 32 byte words to cast to integers.
    /// @return us The array of integers.
    function asUint256Array(bytes32[] memory b32s) internal pure returns (uint256[] memory us) {
        assembly ("memory-safe") {
            us := b32s
        }
    }
}
