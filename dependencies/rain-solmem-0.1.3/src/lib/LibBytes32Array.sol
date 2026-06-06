// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "./LibPointer.sol";
import {OutOfBoundsTruncate} from "../error/ErrUint256Array.sol";

/// @title Bytes32Array
/// @notice Things we want to do carefully and efficiently with bytes32 arrays
/// that Solidity doesn't give us native tools for.
library LibBytes32Array {
    using LibBytes32Array for bytes32[];

    /// Pointer to the start (length prefix) of a `bytes32[]`.
    /// @param array The array to get the start pointer of.
    /// @return pointer The pointer to the start of `array`.
    function startPointer(bytes32[] memory array) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := array
        }
    }

    /// Pointer to the data of a `bytes32[]` NOT the length prefix.
    /// @param array The array to get the data pointer of.
    /// @return pointer The pointer to the data of `array`.
    function dataPointer(bytes32[] memory array) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := add(array, 0x20)
        }
    }

    /// Pointer to the end of the allocated memory of an array.
    /// @param array The array to get the end pointer of.
    /// @return pointer The pointer to the end of `array`.
    function endPointer(bytes32[] memory array) internal pure returns (Pointer pointer) {
        assembly ("memory-safe") {
            pointer := add(array, add(0x20, mul(0x20, mload(array))))
        }
    }

    /// Cast a `Pointer` to `bytes32[]` without modification or safety checks.
    /// The caller MUST ensure the pointer is to a valid region of memory for
    /// some `bytes32[]`.
    /// @param pointer The pointer to cast to `bytes32[]`.
    /// @return array The cast `bytes32[]`.
    function unsafeAsBytes32Array(Pointer pointer) internal pure returns (bytes32[] memory array) {
        assembly ("memory-safe") {
            array := pointer
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a A single integer to build an array around.
    /// @return array The newly allocated array including `a` as a single item.
    function arrayFrom(bytes32 a) internal pure returns (bytes32[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 1)
            mstore(add(array, 0x20), a)
            mstore(0x40, add(array, 0x40))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @return array The newly allocated array including `a` and `b` as the only
    /// items.
    function arrayFrom(bytes32 a, bytes32 b) internal pure returns (bytes32[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 2)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(0x40, add(array, 0x60))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @return array The newly allocated array including `a`, `b` and `c` as the
    /// only items.
    function arrayFrom(bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes32[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 3)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(0x40, add(array, 0x80))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c` and `d` as the
    /// only items.
    function arrayFrom(bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure returns (bytes32[] memory array) {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 4)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(0x40, add(array, 0xA0))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @param e The fifth integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c`, `d` and
    /// `e` as the only items.
    function arrayFrom(bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e)
        internal
        pure
        returns (bytes32[] memory array)
    {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 5)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(add(array, 0xA0), e)
            mstore(0x40, add(array, 0xC0))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @param e The fifth integer to build an array around.
    /// @param f The sixth integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c`, `d`, `e`
    /// and `f` as the only items.
    function arrayFrom(bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e, bytes32 f)
        internal
        pure
        returns (bytes32[] memory array)
    {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 6)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(add(array, 0xA0), e)
            mstore(add(array, 0xC0), f)
            mstore(0x40, add(array, 0xE0))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @param e The fifth integer to build an array around.
    /// @param f The sixth integer to build an array around.
    /// @param g The seventh integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c`, `d`, `e`,
    /// `f` and `g` as the only items.
    function arrayFrom(bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e, bytes32 f, bytes32 g)
        internal
        pure
        returns (bytes32[] memory array)
    {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 7)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(add(array, 0xA0), e)
            mstore(add(array, 0xC0), f)
            mstore(add(array, 0xE0), g)
            mstore(0x40, add(array, 0x100))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first integer to build an array around.
    /// @param b The second integer to build an array around.
    /// @param c The third integer to build an array around.
    /// @param d The fourth integer to build an array around.
    /// @param e The fifth integer to build an array around.
    /// @param f The sixth integer to build an array around.
    /// @param g The seventh integer to build an array around.
    /// @param h The eighth integer to build an array around.
    /// @return array The newly allocated array including `a`, `b`, `c`, `d`, `e`,
    /// `f`, `g` and `h` as the only items.
    function arrayFrom(bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e, bytes32 f, bytes32 g, bytes32 h)
        internal
        pure
        returns (bytes32[] memory array)
    {
        assembly ("memory-safe") {
            array := mload(0x40)
            mstore(array, 8)
            mstore(add(array, 0x20), a)
            mstore(add(array, 0x40), b)
            mstore(add(array, 0x60), c)
            mstore(add(array, 0x80), d)
            mstore(add(array, 0xA0), e)
            mstore(add(array, 0xC0), f)
            mstore(add(array, 0xE0), g)
            mstore(add(array, 0x100), h)
            mstore(0x40, add(array, 0x120))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The head of the new array.
    /// @param tail The tail of the new array.
    /// @return array The new array.
    function arrayFrom(bytes32 a, bytes32[] memory tail) internal pure returns (bytes32[] memory array) {
        assembly ("memory-safe") {
            let length := add(mload(tail), 1)
            let outputCursor := mload(0x40)
            array := outputCursor
            let outputEnd := add(outputCursor, add(0x20, mul(length, 0x20)))
            mstore(0x40, outputEnd)

            mstore(outputCursor, length)
            mstore(add(outputCursor, 0x20), a)

            mcopy(add(outputCursor, 0x40), add(tail, 0x20), mul(mload(tail), 0x20))
        }
    }

    /// Building arrays from literal components is a common task that introduces
    /// boilerplate that is either inefficient or error prone.
    /// @param a The first item of the new array.
    /// @param b The second item of the new array.
    /// @param tail The tail of the new array.
    /// @return array The new array.
    function arrayFrom(bytes32 a, bytes32 b, bytes32[] memory tail) internal pure returns (bytes32[] memory array) {
        assembly ("memory-safe") {
            let length := add(mload(tail), 2)
            let outputCursor := mload(0x40)
            array := outputCursor
            let outputEnd := add(outputCursor, add(0x20, mul(length, 0x20)))
            mstore(0x40, outputEnd)

            mstore(outputCursor, length)
            mstore(add(outputCursor, 0x20), a)
            mstore(add(outputCursor, 0x40), b)

            mcopy(add(outputCursor, 0x60), add(tail, 0x20), mul(mload(tail), 0x20))
        }
    }

    /// Solidity provides no way to change the length of in-memory arrays but
    /// it also does not deallocate memory ever. It is always safe to shrink an
    /// array that has already been allocated, with the caveat that the
    /// truncated items will effectively become inaccessible regions of memory.
    /// That is to say, we deliberately "leak" the truncated items, but that is
    /// no worse than Solidity's native behaviour of leaking everything always.
    /// The array is MUTATED in place so there is no return value and there is
    /// no new allocation or copying of data either.
    /// @param array The array to truncate.
    /// @param newLength The new length of the array after truncation.
    function truncate(bytes32[] memory array, uint256 newLength) internal pure {
        if (newLength > array.length) {
            revert OutOfBoundsTruncate(array.length, newLength);
        }
        assembly ("memory-safe") {
            mstore(array, newLength)
        }
    }

    /// Extends `base_` with `extend_` by allocating only an additional
    /// `extend_.length` words onto `base_` and copying only `extend_` if
    /// possible. If `base_` is large this MAY be significantly more efficient
    /// than allocating `base_.length + extend_.length` for an entirely new array
    /// and copying both `base_` and `extend_` into the new array one item at a
    /// time in Solidity.
    ///
    /// The efficient version of extension is only possible if the free memory
    /// pointer sits at the end of the base array at the moment of extension. If
    /// there is allocated memory after the end of base then extension will
    /// require copying both the base and extend arays to a new region of memory.
    /// The caller is responsible for optimising code paths to avoid additional
    /// allocations.
    ///
    /// This function is UNSAFE because the base array IS MUTATED DIRECTLY by
    /// some code paths AND THE FINAL RETURN ARRAY MAY POINT TO THE SAME REGION
    /// OF MEMORY. It is NOT POSSIBLE to reliably see this behaviour from the
    /// caller in all cases as the Solidity compiler optimisations may switch the
    /// caller between the allocating and non-allocating logic due to subtle
    /// optimisation reasons. To use this function safely THE CALLER MUST NOT USE
    /// THE BASE ARRAY AND MUST USE THE RETURNED ARRAY ONLY. It is safe to use
    /// the extend array after calling this function as it is never mutated, it
    /// is only copied from.
    ///
    /// @param b The base integer array that will be extended by `e`.
    /// @param e The extend integer array that extends `b`.
    /// @return extended The extended array of `b` extended by `e`.
    function unsafeExtend(bytes32[] memory b, bytes32[] memory e) internal pure returns (bytes32[] memory extended) {
        assembly ("memory-safe") {
            // Slither doesn't recognise assembly function names as mixed case
            // even if they are.
            // https://github.com/crytic/slither/issues/1815
            //slither-disable-next-line naming-convention
            function extendInline(base, extend) -> baseAfter {
                let outputCursor := mload(0x40)
                let baseLength := mload(base)
                let baseEnd := add(base, add(0x20, mul(baseLength, 0x20)))

                // If base is NOT the last thing in allocated memory, allocate,
                // copy and recurse.
                switch eq(outputCursor, baseEnd)
                case 0 {
                    let newBase := outputCursor
                    // Base size includes the length word and is in bytes.
                    let newBaseSize := sub(baseEnd, base)
                    let newBaseEnd := add(newBase, newBaseSize)
                    mstore(0x40, newBaseEnd)
                    mcopy(newBase, base, newBaseSize)

                    baseAfter := extendInline(newBase, extend)
                }
                case 1 {
                    let totalLength := add(baseLength, mload(extend))
                    let outputEnd := add(base, add(0x20, mul(totalLength, 0x20)))
                    mstore(base, totalLength)
                    mstore(0x40, outputEnd)
                    mcopy(baseEnd, add(extend, 0x20), mul(mload(extend), 0x20))

                    baseAfter := base
                }
            }

            extended := extendInline(b, e)
        }
    }

    /// Reverse an array in place. This is a destructive operation that MUTATES
    /// the array in place. There is no return value.
    /// @param array The array to reverse.
    function reverse(bytes32[] memory array) internal pure {
        assembly ("memory-safe") {
            for {
                let left := add(array, 0x20)
                // Right points at the last item in the array. Which is the
                // length number of items from the length.
                let right := add(array, mul(mload(array), 0x20))
            } lt(left, right) {
                left := add(left, 0x20)
                right := sub(right, 0x20)
            } {
                let leftValue := mload(left)
                mstore(left, mload(right))
                mstore(right, leftValue)
            }
        }
    }
}
