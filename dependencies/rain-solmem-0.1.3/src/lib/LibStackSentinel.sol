// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "./LibPointer.sol";

/// Thrown when the sentinel tuple size is zero.
error ZeroSentinelTupleSize();

/// Thrown when the sentinel cannot be found. This can be because the sentinel
/// was not in stack, but also if the upper pointer is below the lower, or the
/// sentinel is in the stack but not aligned with the tuples size.
/// @param sentinel The sentinel that was not found.
error MissingSentinel(Sentinel sentinel);

/// Thrown when the stack bounds are invalid because the lower is above the
/// upper.
/// @param lower The lower stack pointer.
/// @param upper The upper stack pointer.
error InvalidStackBounds(Pointer lower, Pointer upper);

/// > In computer programming, a sentinel value (also referred to as a flag
/// > value, trip value, rogue value, signal value, or dummy data)[1] is a
/// > special value in the context of an algorithm which uses its presence as a
/// > condition of termination, typically in a loop or recursive algorithm.
/// >
/// > The sentinel value is a form of in-band data that makes it possible to
/// > detect the end of the data when no out-of-band data (such as an explicit
/// > size indication) is provided. The value should be selected in such a way
/// > that it is guaranteed to be distinct from all legal data values since
/// > otherwise, the presence of such values would prematurely signal the end of
/// > the data (the semipredicate problem).
/// >
/// > - [Wikipedia](https://en.wikipedia.org/wiki/Sentinel_value)
type Sentinel is uint256;

/// Rainlang has no dynamic list data type as every stack item MUST be explicit
/// in the structure of the code itself. While it would be possible for users to
/// manually code length prefixes into the stack, this would be error prone and
/// generally hostile to the overall DX. Instead we can allow sentinels as an
/// option that is merely awkward rather than downright pathological.
///
/// Rainlang authors can use a single sentinel value that is constant across all
/// their expressions rather than a calculated length prefix. This value can even
/// be aliased in onchain metadata and referenced by name for ease of use. The
/// calling contract defines and consumes sentinels, so the expression author
/// does not need to be aware of or have control over any subtleties in choice of
/// sentinel.
///
/// The main tradeoffs for sentinel terminated lists on a stack are similar to
/// null-terminated strings,
/// as per [Wikipedia](https://en.wikipedia.org/wiki/Null-terminated_string)
///
/// > While simple to implement, this representation has been prone to errors and
/// > performance problems.
///
/// This library attempts to mitigate potential implementation errors with a
/// standard implementation that has been fuzzed and optimized for building lists
/// of tuples (and therefore lists of structs via. a direct type cast). The main
/// implementation issues in null-terminated strings are avoided:
///
/// - Using any sentinel value other than `0`, such as the hash of some well
///   known string, will avoid misinterpreting unallocated memory as a sentinel.
/// - Any underflows manifest as either a "missing sentinel" or infinite loop,
///   which will revert either way due to an explicit check or gas limits.
/// - Given that a sentinel is `uint256` it is possible to construct a value that
///   is very unlikely to collide with real values in the implementation domain.
/// - Well behaved integrity checks will ensure the memory for the sentinel is
///   allocated as any other stack item.
///
/// Sadly there is no way to avoid the O(n) performance overhead of searching for
/// a sentinel vs. O(1) of reading a length prefix directly. This is somewhat
/// mitigated by the nature of a hand-written stack being small in
/// computing terms, and that each item being iterated over is an entire struct
/// rather than individual stack values. Assembly is used to keep the looping
/// overhead to a minimum.
library LibStackSentinel {
    using LibStackSentinel for Pointer;

    /// Given two stack pointers that bound a stack build an array of `n` item
    /// tuples above the given sentinel value. The sentinel will be skipped and
    /// a pointer below it returned alongside the tuples list.
    ///
    /// The tuples can be cast (via assembly) to structs.
    ///
    /// The caller MUST consider the region of memory consumed for the structs as
    /// mutated/truncated/deallocated and reallocated insitu to the tuples.
    ///
    /// The sentinel MUST be chosen to have a negligible chance of colliding with
    /// a real value in the array, otherwise an intended array item will be
    /// interpreted as a sentinel.
    ///
    /// If the sentinel is absent in the stack this WILL REVERT. The intent is
    /// to represent dynamic length arrays without forcing expression authors to
    /// calculate lengths on the stack. If the expression author wants to model
    /// an empty/optional/absent value they MAY provided a sentinel for a zero
    /// length array and the calling contract SHOULD handle this.
    ///
    /// If `lower` is smaller than `n` it is possible that this will underflow
    /// which will result in the evm immediately running out of gas as it
    /// attempts to loop from infinity. There is no explicit underflow check but
    /// there is no way to underflow without reverting due to gas.
    ///
    /// @param upper Pointer to the top of the stack range.
    /// @param lower Pointer to the bottom of the stack range.
    /// @param sentinel The value to expect as the sentinel. MUST be present in
    /// the stack or `consumeSentinel` will revert. MUST NOT collide with valid
    /// stack items (or be cryptographically improbable to do so).
    /// @param n The number of items per tuple.
    /// @return sentinelPointer Pointer to the sentinel that was found. A missing
    /// sentinel WILL REVERT.
    /// @return tuplesPointer Pointer to the n-item tuples array that was built.
    function consumeSentinelTuples(Pointer lower, Pointer upper, Sentinel sentinel, uint256 n)
        internal
        pure
        returns (Pointer sentinelPointer, Pointer tuplesPointer)
    {
        if (n == 0) {
            revert ZeroSentinelTupleSize();
        }

        // Each tuple takes this much space in memory.
        uint256 size;

        // First pass to find the sentinel.
        assembly ("memory-safe") {
            size := mul(n, 0x20)
            // An underflow here always results in a revert due to gas.
            for { let cursor := upper } gt(cursor, lower) { cursor := sub(cursor, size) } {
                let potentialSentinelPointer := sub(cursor, 0x20)
                if eq(mload(potentialSentinelPointer), sentinel) {
                    sentinelPointer := potentialSentinelPointer
                    break
                }
            }
        }

        // We revert if the sentinel was not found.
        if (Pointer.unwrap(sentinelPointer) == 0) {
            if (Pointer.unwrap(upper) < Pointer.unwrap(lower)) {
                revert InvalidStackBounds(lower, upper);
            }
            revert MissingSentinel(sentinel);
        }

        // Second pass to build references _in order_ from the sentinel back up
        // to upper.
        assembly ("memory-safe") {
            tuplesPointer := mload(0x40)
            let tuplesCursor := add(tuplesPointer, 0x20)
            for { let cursor := add(sentinelPointer, 0x20) } lt(cursor, upper) {
                tuplesCursor := add(tuplesCursor, 0x20)
                cursor := add(cursor, size)
            } {
                // Write the reference to the tuple.
                mstore(tuplesCursor, cursor)
            }
            // Update allocated memory pointer past the tuples.
            mstore(0x40, tuplesCursor)
            // Store tuples length.
            mstore(tuplesPointer, sub(div(sub(tuplesCursor, tuplesPointer), 0x20), 1))
        }
    }
}
