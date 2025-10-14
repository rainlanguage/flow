// SPDX-License-Identifier: CAL
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";

import {ECDSAUpgradeable as ECDSA} from "openzeppelin/utils/cryptography/ECDSAUpgradeable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

library SignContextLib {
    function signContext(Vm vm, uint256 signerPrivateKey, uint256 signaturePrivateKey, uint256[] memory context)
        internal
        pure
        returns (SignedContextV1 memory)
    {
        SignedContextV1 memory signedContext;

        // Store the signer's address in the struct
        signedContext.signer = vm.addr(signerPrivateKey);
        signedContext.context = context; // copy the context data into the struct

        // Create a digest of the context data
        bytes32 contextHash = keccak256(abi.encodePacked(context));
        bytes32 digest = ECDSA.toEthSignedMessageHash(contextHash);

        // Create the signature using the cheatCode 'sign'
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signaturePrivateKey, digest);
        signedContext.signature = abi.encodePacked(r, s, v);

        return signedContext;
    }
}
