// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibUint256Array} from "./LibUint256Array.sol";
import {Pointer} from "./LibMemCpy.sol";
import {UnalignedStackPointer} from "../error/ErrStackPointer.sol";

/// @title LibStackPointer
/// @notice A stack `Pointer` is still just a pointer to some memory, but we are
/// going to treat it like it is pointing to a stack data structure. That means
/// it can move "up" and "down" (increment and decrement) by `uint256` (32 bytes)
/// increments. Structurally a stack is a `uint256[]` but we can save a lot of
/// gas vs. default Solidity handling of array indexes by using assembly to
/// bypass runtime bounds checks on every read and write. Of course, this means
/// the caller is responsible for ensuring the stack reads and write are not out
/// of bounds.
///
/// The pointer to the bottom of a stack points at the 0th item, NOT the length
/// of the implied `uint256[]` and the top of a stack points AFTER the last item.
/// e.g. consider a `uint256[]` in memory with values `3 A B C` and assume this
/// starts at position `0` in memory, i.e. `0` points to value `3` for the
/// array length. In this case the stack bottom would be `Pointer.wrap(0x20)`
/// (32 bytes above 0, past the length) and the stack top would be
/// `StackPointer.wrap(0x80)` (96 bytes above the stack bottom).
///
/// Most of the functions in this library are equivalent to each other via
/// composition, i.e. everything could be achieved with just `up`, `down`,
/// `pop`, `push`, `peek`. The reason there is so much overloaded/duplicated
/// logic is that the Solidity compiler seems to fail at inlining equivalent
/// logic quite a lot. Perhaps once the IR compilation of Solidity is better
/// supported by tooling etc. we could remove a lot of this duplication as the
/// compiler itself would handle the optimisations.
library LibStackPointer {
    using LibStackPointer for Pointer;
    using LibStackPointer for uint256[];
    using LibStackPointer for bytes;
    using LibUint256Array for uint256[];

    /// Read the word immediately below the given stack pointer.
    ///
    /// Treats the given pointer as a pointer to the top of the stack, so `peek`
    /// reads the word below the pointer.
    ///
    /// https://en.wikipedia.org/wiki/Peek_(data_type_operation)
    ///
    /// The caller MUST ensure this read is not out of bounds, e.g. a `peek` to
    /// `0` will underflow (and exhaust gas attempting to read).
    ///
    /// @param pointer Pointer to the top of the stack to read below.
    /// @return word The word that was read.
    function unsafePeek(Pointer pointer) internal pure returns (bytes32 word) {
        assembly ("memory-safe") {
            word := mload(sub(pointer, 0x20))
        }
    }

    /// Peeks 2 words from the top of the stack.
    ///
    /// Same as `unsafePeek` but returns 2 words instead of 1.
    ///
    /// @param pointer The stack top to peek below.
    /// @return lower The lower of the two words read.
    /// @return upper The upper of the two words read.
    function unsafePeek2(Pointer pointer) internal pure returns (bytes32 lower, bytes32 upper) {
        assembly ("memory-safe") {
            lower := mload(sub(pointer, 0x40))
            upper := mload(sub(pointer, 0x20))
        }
    }

    /// Pops the word from the top of the stack.
    ///
    /// Treats the given pointer as a pointer to the top of the stack, so `pop`
    /// reads the word below the pointer. The popped pointer is returned
    /// alongside the read word.
    ///
    /// https://en.wikipedia.org/wiki/Stack_(abstract_data_type)
    ///
    /// The caller MUST ensure the pop will not result in an out of bounds read.
    ///
    /// @param pointer Pointer to the top of the stack to read below.
    /// @return pointerAfter Pointer after the pop.
    /// @return word The word that was read.
    function unsafePop(Pointer pointer) internal pure returns (Pointer pointerAfter, bytes32 word) {
        assembly ("memory-safe") {
            pointerAfter := sub(pointer, 0x20)
            word := mload(pointerAfter)
        }
    }

    /// Pushes a word to the top of the stack.
    ///
    /// Treats the given pointer as a pointer to the top of the stack, so `push`
    /// writes a word at the pointer. The pushed pointer is returned.
    ///
    /// https://en.wikipedia.org/wiki/Stack_(abstract_data_type)
    ///
    /// The caller MUST ensure the push will not result in an out of bounds
    /// write.
    ///
    /// @param pointer The stack pointer to write at.
    /// @param word The value to write.
    /// @return The stack pointer above where `word` was written to.
    function unsafePush(Pointer pointer, bytes32 word) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            mstore(pointer, word)
            pointer := add(pointer, 0x20)
        }
        return pointer;
    }

    /// Returns `length` values from the stack as an array without allocating
    /// new memory. As arrays always start with their length, this requires
    /// writing the length value to the stack below the array values. The value
    /// that is overwritten in the process is also returned so that data is not
    /// lost. For example, imagine a stack `[ A B C D ]` and we list 2 values.
    /// This will write the stack to look like `[ A 2 C D ]` and return both `B`
    /// and a pointer to `2` represented as a `uint256[]`.
    /// The returned array is ONLY valid for as long as the stack DOES NOT move
    /// back into its memory. As soon as the stack moves up again and writes into
    /// the array it will be corrupt. The caller MUST ensure that it does not
    /// read from the returned array after it has been corrupted by subsequent
    /// stack writes.
    /// The caller is responsible for ensuring that `pointer` and `length` are
    /// built from a real Solidity array, ensuring that the reads and writes in
    /// this function do not underflow the original array. Specifically that
    /// `length` is not greater than the number of items in the array below
    /// `pointer`.
    /// @param pointer The stack pointer to read the values below into an
    /// array.
    /// @param length The number of values to include in the returned array.
    /// @return head The value that was overwritten with the length.
    /// @return tail The array constructed from the stack memory.
    function unsafeList(Pointer pointer, uint256 length) internal pure returns (bytes32 head, bytes32[] memory tail) {
        assembly ("memory-safe") {
            tail := sub(pointer, add(0x20, mul(length, 0x20)))
            head := mload(tail)
            mstore(tail, length)
        }
    }

    /// Convert two stack pointer values to a single stack index. A stack index
    /// is the distance in 32 byte increments between two stack pointers. The
    /// calculations require the two stack pointers are aligned. If the pointers
    /// are not aligned, the function will revert.
    ///
    /// @param lower The lower of the two values.
    /// @param upper The higher of the two values.
    /// @return The stack index as 32 byte words distance between the top and
    /// bottom. Negative if `lower` is above `upper`.
    function toIndexSigned(Pointer lower, Pointer upper) internal pure returns (int256) {
        unchecked {
            uint256 distance = Pointer.unwrap(upper) >= Pointer.unwrap(lower)
                ? Pointer.unwrap(upper) - Pointer.unwrap(lower)
                : Pointer.unwrap(lower) - Pointer.unwrap(upper);

            if (distance % 0x20 != 0) {
                revert UnalignedStackPointer(lower, upper);
            }
            // Dividing by 0x20 before casting to a signed int avoids the case
            // where the difference between the two pointers is greater than
            // `type(int256).max` and would overflow the signed int.
            return int256(Pointer.unwrap(upper) / 0x20) - int256(Pointer.unwrap(lower) / 0x20);
        }
    }
}
