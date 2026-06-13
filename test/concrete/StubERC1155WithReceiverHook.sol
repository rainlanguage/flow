// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

/// Minimal ERC1155-shaped stub that, on `safeTransferFrom`, calls the
/// recipient's `onERC1155Received` hook if the recipient has code. Used
/// in tests to exercise recipient-side reentrancy through the ERC1155
/// path without deploying a full ERC1155 token implementation.
contract StubERC1155WithReceiverHook {
    //forge-lint: disable-next-line(mixed-case-function)
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external {
        if (to.code.length > 0) {
            IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, amount, data);
        }
    }
}
