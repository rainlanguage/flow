// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";

import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/deprecated/v1/IInterpreterCallerV2.sol";

library SignContextLib {
    function signContext(Vm vm, uint256 signerPrivateKey, uint256 signaturePrivateKey, uint256[] memory context)
        internal
        pure
        returns (SignedContextV1 memory)
    {
        SignedContextV1 memory signedContext;

        // Store the signer's address in the struct
        signedContext.signer = vm.addr(signerPrivateKey);
        bytes32[] memory ctx;
        assembly ("memory-safe") {
            ctx := context
        }
        signedContext.context = ctx; // copy the context data into the struct

        // Create a digest of the context data
        bytes32 contextHash = keccak256(abi.encodePacked(context));
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(contextHash);

        // Create the signature using the cheatCode 'sign'
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signaturePrivateKey, digest);
        signedContext.signature = abi.encodePacked(r, s, v);

        return signedContext;
    }
}
