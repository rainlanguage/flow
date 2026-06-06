// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.19;

import {IMetaV1} from "./IMetaV1.sol";

/// Defines a general purpose contract that anon may call to emit ANY metadata.
/// Anons MAY send garbage and malicious metadata so it is up to tooling to
/// discard any suspect data before use, and generally treat it all as untrusted.
interface IMetaBoardV1 is IMetaV1 {
    /// Emit a single MetaV1 event. Typically this is sufficient for most use
    /// cases as a single MetaV1 event can contain many metas as a single
    /// cbor-seq. Metadata MUST match the metadata V1 specification for Rain
    /// metadata or tooling MAY drop it. `IMetaBoardV1` contracts MUST revert any
    /// metadata that does not start with the Rain metadata magic number.
    /// @param subject As per `IMetaV1` event.
    /// @param meta As per `IMetaV1` event.
    function emitMeta(uint256 subject, bytes calldata meta) external;
}
