// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IFlowV5} from "../../src/interface/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

/// A recipient whose ERC721 / ERC1155 receiver hooks re-enter
/// `flow.flow(...)` on the same flow contract. Used to exercise
/// `Flow.flow`'s `nonReentrant` guard against reentry through the
/// EIP-721 / EIP-1155 receiver-side hooks.
contract MaliciousReenteringRecipient is IERC721Receiver, IERC1155Receiver {
    IFlowV5 internal immutable I_FLOW;
    EvaluableV2 internal evaluable;

    constructor(IFlowV5 flow_) {
        I_FLOW = flow_;
    }

    function setEvaluable(EvaluableV2 memory ev) external {
        evaluable = ev;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        I_FLOW.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        I_FLOW.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        I_FLOW.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
            || interfaceId == 0x01ffc9a7;
    }
}
