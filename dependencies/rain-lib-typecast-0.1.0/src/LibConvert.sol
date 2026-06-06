// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title LibConvert
/// @notice Type conversions that require additional structural changes to
/// complete safely. These are NOT mere type casts and involve additional
/// reads and writes to complete, such as recalculating the length of an array.
/// The convention "toX" is adopted from Rust to imply the additional costs and
/// consumption of the source to produce the target.
library LibConvert {
    /// Convert an array of integers to `bytes` data. This requires modifying
    /// the length in situ as the integer array length is measured in 32 byte
    /// increments while the length of `bytes` is the literal number of bytes.
    ///
    /// It is unsafe for the caller to use `us` after it has been converted to
    /// bytes because there is now two pointers to the same mutable data
    /// structure AND the length prefix for the `uint256[]` version is corrupt.
    ///
    /// @param us The integer array to convert to `bytes`.
    /// @return bs The integer array converted to `bytes` data.
    function unsafeToBytes(uint256[] memory us) internal pure returns (bytes memory bs) {
        assembly ("memory-safe") {
            bs := us
            // Length in bytes is 32x the length in uint256
            mstore(bs, mul(0x20, mload(bs)))
        }
    }

    /// Truncate `uint256[]` values down to `uint16[]` then pack this to `bytes`
    /// without padding or length prefix. Unsafe because the starting `uint256`
    /// values are not checked for overflow due to the truncation. The caller
    /// MUST ensure that all values fit in `type(uint16).max` or that silent
    /// overflow is safe.
    /// @param us The `uint256[]` to truncate and concatenate to 16 bit `bytes`.
    /// @return The concatenated 2-byte chunks.
    function unsafeTo16BitBytes(uint256[] memory us) internal pure returns (bytes memory) {
        unchecked {
            // We will keep 2 bytes (16 bits) from each integer.
            bytes memory bs = new bytes(us.length * 2);
            assembly ("memory-safe") {
                let replaceMask := 0xFFFF
                let preserveMask := not(replaceMask)
                for {
                    let cursor := add(us, 0x20)
                    let end := add(cursor, mul(mload(us), 0x20))
                    let bytesCursor := add(bs, 0x02)
                } lt(cursor, end) {
                    cursor := add(cursor, 0x20)
                    bytesCursor := add(bytesCursor, 0x02)
                } {
                    let data := mload(bytesCursor)
                    mstore(bytesCursor, or(and(preserveMask, data), and(replaceMask, mload(cursor))))
                }
            }
            return bs;
        }
    }
}
