// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "../lib/LibMemCpy.sol";

/// Throws if two stack pointers are unaligned with each other (32 bytes).
/// @param lower The lower stack pointer.
/// @param upper The upper stack pointer.
error UnalignedStackPointer(Pointer lower, Pointer upper);
