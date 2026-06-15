// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

/// Minimal ERC721-shaped stub that, on `safeTransferFrom`, calls the
/// recipient's `onERC721Received` hook if the recipient has code. Used in
/// tests to exercise recipient-side reentrancy through the ERC721 path
/// without deploying a full ERC721 token implementation.
contract StubERC721WithReceiverHook {
    //forge-lint: disable-next-line(mixed-case-function)
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        if (to.code.length > 0) {
            IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
        }
    }
}
