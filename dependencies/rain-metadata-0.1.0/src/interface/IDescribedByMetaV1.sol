// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.19;

/// @title IDescribedByMetaV1
/// An interface for contracts that describe themselves with Rain metadata V1.
/// Only the hash of the metadata is stored onchain, most likely compiled into
/// the contract directly for gas efficiency. The metadata itself is expected to
/// be available offchain, e.g. by emitting it via the metaboard contract.
///
/// The implementing contract DOES NOT need to emit the metadata itself, nor be
/// the subject of the metadata. The emitter of the metadata is NOT expected to
/// even be aware of the contract that implements this interface.
///
/// Importantly, this interface implies the existence of an indexer that can
/// retrieve the metadata for a given hash.
///
/// The implementing contract MUST NOT change the metadata hash after deployment.
/// It is expected that the metadata associated with the contract is an immutable
/// and intrinsic part of the contract's identity.
///
/// The main benefit of this interface is to allow contracts to be
/// self-describing, without suffering the bloat of the metadata itself.
interface IDescribedByMetaV1 {
    /// @return The hash of the metadata that describes this contract.
    function describedByMetaV1() external view returns (bytes32);
}
