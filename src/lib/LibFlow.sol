// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {
    FlowTransferV1,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    RAIN_FLOW_SENTINEL,

    //forge-lint: disable-next-line(unused-import)
    IFlowV5
} from "../interface/IFlowV5.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {UnsupportedERC20Flow, UnsupportedERC721Flow, UnsupportedERC1155Flow} from "../error/ErrFlow.sol";

/// @title LibFlow
/// Standard processing used by all variants of `Flow`. These utilities can't
/// be directly embedded in `FlowCommon` because each variant of `Flow` has
/// slightly different requirements to incorporate mints and burns as well as
/// the basic transfer handling.
library LibFlow {
    using SafeERC20 for IERC20;
    using LibStackSentinel for Pointer;
    using LibFlow for FlowTransferV1;

    /// Converts pointers bounding an evaluated stack to a `FlowTransferV1`.
    /// Works by repeatedly consuming sentinel tuples from the stack, where the
    /// tuple size is 4 for ERC20, 4 for ERC721 and 5 for ERC1155. The sentinels
    /// are consumed from the stack from top to bottom, so the first sentinels
    /// consumed are the ERC20 transfers, followed by the ERC721 transfers and
    /// finally the ERC1155 transfers.
    /// @param stackBottom The bottom of the stack.
    /// @param stackTop The top of the stack.
    /// @return The `FlowTransferV1` representing the transfers in the stack.
    function stackToFlow(Pointer stackBottom, Pointer stackTop) internal pure returns (FlowTransferV1 memory) {
        unchecked {
            ERC20Transfer[] memory erc20;
            ERC721Transfer[] memory erc721;
            ERC1155Transfer[] memory erc1155;
            Pointer tuplesPointer;
            // erc20: each tuple is 4 stack words read top-down as
            // (token, from, to, amount). The cast below reinterprets the
            // tuple memory as `ERC20Transfer[]`; this is only correct so
            // long as `ERC20Transfer` declares fields in exactly that order.
            (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 4);
            assembly ("memory-safe") {
                erc20 := tuplesPointer
            }
            // erc721: each tuple is 4 stack words read top-down as
            // (token, from, to, id). `ERC721Transfer` field order must match.
            (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 4);
            assembly ("memory-safe") {
                erc721 := tuplesPointer
            }
            // erc1155: each tuple is 5 stack words read top-down as
            // (token, from, to, id, amount). `ERC1155Transfer` field order
            // must match.
            (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 5);
            assembly ("memory-safe") {
                erc1155 := tuplesPointer
            }
            return FlowTransferV1(erc20, erc721, erc1155);
        }
    }

    /// Processes the ERC20 transfers in the flow.
    /// Reverts if the `from` address is not either the `msg.sender` or the
    /// flow contract. Uses `IERC20.safeTransferFrom(from, to, amount)` when
    /// `from == msg.sender` and `IERC20.safeTransfer(to, amount)` when
    /// `from == address(this)` — the self-flow branch must use
    /// `safeTransfer` because OZ `transferFrom` consumes allowance even
    /// when `from == msg.sender`. Both branches surface token reverts.
    /// @param flowTransfer The `FlowTransferV1` to process. Tokens other than
    /// ERC20 tokens are ignored.
    function flowERC20(FlowTransferV1 memory flowTransfer) internal {
        unchecked {
            ERC20Transfer memory transfer;
            for (uint256 i = 0; i < flowTransfer.erc20.length; ++i) {
                transfer = flowTransfer.erc20[i];
                // We don't support `from` as anyone other than `you` or `me`
                // as this would allow for all kinds of issues re: approvals.
                if (transfer.from != msg.sender && transfer.from != address(this)) {
                    revert UnsupportedERC20Flow();
                }
                // OZ ERC20 `transferFrom` consumes allowance even when
                // `from == msg.sender`, so the self-flow branch must use
                // `safeTransfer` instead.
                if (transfer.from == msg.sender) {
                    IERC20(transfer.token).safeTransferFrom(msg.sender, transfer.to, transfer.amount);
                } else {
                    IERC20(transfer.token).safeTransfer(transfer.to, transfer.amount);
                }
            }
        }
    }

    /// Processes the ERC721 transfers in the flow.
    /// Reverts if the `from` address is not either the `msg.sender` or the
    /// flow contract. Uses `IERC721.safeTransferFrom` to transfer the tokens to
    /// ensure that reverts from the token are respected.
    /// @param flowTransfer The `FlowTransferV1` to process. Tokens other than
    /// ERC721 tokens are ignored.
    function flowERC721(FlowTransferV1 memory flowTransfer) internal {
        unchecked {
            ERC721Transfer memory transfer;
            for (uint256 i = 0; i < flowTransfer.erc721.length; ++i) {
                transfer = flowTransfer.erc721[i];
                if (transfer.from != msg.sender && transfer.from != address(this)) {
                    revert UnsupportedERC721Flow();
                }
                IERC721(transfer.token).safeTransferFrom(transfer.from, transfer.to, transfer.id);
            }
        }
    }

    /// Processes the ERC1155 transfers in the flow.
    /// Reverts if the `from` address is not either the `msg.sender` or the
    /// flow contract. Uses `IERC1155.safeTransferFrom` to transfer the tokens to
    /// ensure that reverts from the token are respected.
    /// @param flowTransfer The `FlowTransferV1` to process. Tokens other than
    /// ERC1155 tokens are ignored.
    function flowERC1155(FlowTransferV1 memory flowTransfer) internal {
        unchecked {
            ERC1155Transfer memory transfer;
            for (uint256 i = 0; i < flowTransfer.erc1155.length; ++i) {
                transfer = flowTransfer.erc1155[i];
                if (transfer.from != msg.sender && transfer.from != address(this)) {
                    revert UnsupportedERC1155Flow();
                }
                IERC1155(transfer.token).safeTransferFrom(transfer.from, transfer.to, transfer.id, transfer.amount, "");
            }
        }
    }

    /// Processes a flow transfer. Firstly sets state for the interpreter on the
    /// interpreter store. Then processes the ERC20, ERC721 and ERC1155 transfers
    /// in this order: all ERC20 transfers in `flowTransfer.erc20` array
    /// index order, then all ERC721 transfers in `flowTransfer.erc721`
    /// array index order, then all ERC1155 transfers in
    /// `flowTransfer.erc1155` array index order.
    /// DOES NOT prevent reentrancy attacks. This is the responsibility of
    /// the caller.
    /// `set` is skipped entirely when `kvs.length == 0`. Stores that need to
    /// observe every flow invocation (e.g. for audit logging) cannot rely on
    /// `set` being called for empty kvs.
    /// @param flowTransfer The `FlowTransferV1` to process.
    /// @param interpreterStore The `IInterpreterStoreV2` to set state on.
    /// @param kvs The key value pairs to set on the interpreter store.
    function flow(FlowTransferV1 memory flowTransfer, IInterpreterStoreV2 interpreterStore, uint256[] memory kvs)
        internal
    {
        if (kvs.length > 0) {
            interpreterStore.set(DEFAULT_STATE_NAMESPACE, kvs);
        }
        flowTransfer.flowERC20();
        flowTransfer.flowERC721();
        flowTransfer.flowERC1155();
    }
}
