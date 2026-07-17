// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {FlowTransferV1} from "../../src/interface/IFlowV6.sol";

library LibStackGeneration {
    function generateFlowStack(uint256 sentinel, FlowTransferV1 memory flowTransfer)
        internal
        pure
        returns (uint256[] memory stack)
    {
        uint256 totalItems = 1 + (flowTransfer.erc1155.length * 5) + 1 + (flowTransfer.erc721.length * 4) + 1
            + (flowTransfer.erc20.length * 4);
        stack = new uint256[](totalItems);
        uint256 index = 0;

        stack[index++] = sentinel;
        for (uint256 i = 0; i < flowTransfer.erc1155.length; i++) {
            stack[index++] = uint256(uint160(flowTransfer.erc1155[i].token));
            stack[index++] = uint256(uint160(flowTransfer.erc1155[i].from));
            stack[index++] = uint256(uint160(flowTransfer.erc1155[i].to));
            stack[index++] = flowTransfer.erc1155[i].id;
            stack[index++] = flowTransfer.erc1155[i].amount;
        }

        stack[index++] = sentinel;
        for (uint256 i = 0; i < flowTransfer.erc721.length; i++) {
            stack[index++] = uint256(uint160(flowTransfer.erc721[i].token));
            stack[index++] = uint256(uint160(flowTransfer.erc721[i].from));
            stack[index++] = uint256(uint160(flowTransfer.erc721[i].to));
            stack[index++] = flowTransfer.erc721[i].id;
        }

        stack[index++] = sentinel;
        for (uint256 i = 0; i < flowTransfer.erc20.length; i++) {
            stack[index++] = uint256(uint160(flowTransfer.erc20[i].token));
            stack[index++] = uint256(uint160(flowTransfer.erc20[i].from));
            stack[index++] = uint256(uint160(flowTransfer.erc20[i].to));
            stack[index++] = flowTransfer.erc20[i].amount;
        }

        return stack;
    }
}
