// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {MissingSentinel, Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {
    IFlowV5,
    FlowTransferV1,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    RAIN_FLOW_SENTINEL,
    Sentinel
} from "../../../src/interface/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract FlowPreviewTest is FlowTest {
    using LibEvaluable for EvaluableV2;

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasePreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));
        {
            (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                multiTransferERC1155(alice, address(flow), erc1155TokenId, erc1155Amount, erc1155TokenId, erc1155Amount)
            );

            assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
        }
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     * using multi-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasePreviewDefinedFlowIOForERC721MultiElementArrays(
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, 5, multiTransferERC721(alice, address(flow), erc721TokenIdA, erc721TokenIdB)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     * using multi-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasePreviewDefinedFlowIOForERC20MultiElementArrays(
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, 5, multiTransfersERC20(alice, address(flow), erc20AmountA, erc20AmountB)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     * using single-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasePreviewDefinedFlowIOForERC1155SingleElementArrays(
        address alice,
        uint256 erc1155TokenId,
        uint256 erc1155Amount
    ) external {
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            5,
            createTransferERC1155ToERC1155(
                alice, address(flow), erc1155TokenId, erc1155Amount, erc1155TokenId, erc1155Amount
            )
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     * using single-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasePreviewDefinedFlowIOForERC721SingleElementArrays(
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            5,
            createTransferERC721ToERC721(alice, address(flow), erc721TokenInId, erc721TokenOutId)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     * using single-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasePreviewDefinedFlowIOForERC20SingleElementArrays(
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            5,
            createTransfersERC20toERC20(alice, address(flow), erc20AmountIn, erc20AmountOut)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasePreviewEmptyFlowIO() public {
        (IFlowV5 flow,) = deployFlow();

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0));
        uint256[] memory stack = LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), flowTransfer);
        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /// Pins the positional layout of stack tuples against the named fields of
    /// `ERC20Transfer` / `ERC721Transfer` / `ERC1155Transfer`. The stack is
    /// authored by hand with distinct markers per field — exactly what a
    /// rainlang author writes — so that any future reorder of the struct
    /// fields produces field-named assertions that fail.
    function testFlowStackToFlowFieldOrderPinned() external {
        (IFlowV5 flow,) = deployFlow();

        // Stack layout (low index = bottom of stack, high index = top; top is
        // consumed first by stackToFlow):
        //   [sentinel, erc1155 tuple (5), sentinel, erc721 tuple (4), sentinel, erc20 tuple (4)]
        // Markers chosen so each field is unique: top nibble = token type
        // (A=erc20, B=erc721, C=erc1155), next nibble = field index in tuple.
        uint256[] memory stack = new uint256[](16);
        stack[0] = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        stack[1] = uint256(uint160(0xC0)); // erc1155 token
        stack[2] = uint256(uint160(0xC1)); // erc1155 from
        stack[3] = uint256(uint160(0xC2)); // erc1155 to
        stack[4] = 0xC3C3; // erc1155 id
        stack[5] = 0xC4C4; // erc1155 amount
        stack[6] = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        stack[7] = uint256(uint160(0xB0)); // erc721 token
        stack[8] = uint256(uint160(0xB1)); // erc721 from
        stack[9] = uint256(uint160(0xB2)); // erc721 to
        stack[10] = 0xB3B3; // erc721 id
        stack[11] = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        stack[12] = uint256(uint160(0xA0)); // erc20 token
        stack[13] = uint256(uint160(0xA1)); // erc20 from
        stack[14] = uint256(uint160(0xA2)); // erc20 to
        stack[15] = 0xA3A3; // erc20 amount

        FlowTransferV1 memory result = flow.stackToFlow(stack);

        assertEq(result.erc20.length, 1, "erc20 length");
        assertEq(result.erc20[0].token, address(uint160(0xA0)), "erc20 token");
        assertEq(result.erc20[0].from, address(uint160(0xA1)), "erc20 from");
        assertEq(result.erc20[0].to, address(uint160(0xA2)), "erc20 to");
        assertEq(result.erc20[0].amount, 0xA3A3, "erc20 amount");

        assertEq(result.erc721.length, 1, "erc721 length");
        assertEq(result.erc721[0].token, address(uint160(0xB0)), "erc721 token");
        assertEq(result.erc721[0].from, address(uint160(0xB1)), "erc721 from");
        assertEq(result.erc721[0].to, address(uint160(0xB2)), "erc721 to");
        assertEq(result.erc721[0].id, 0xB3B3, "erc721 id");

        assertEq(result.erc1155.length, 1, "erc1155 length");
        assertEq(result.erc1155[0].token, address(uint160(0xC0)), "erc1155 token");
        assertEq(result.erc1155[0].from, address(uint160(0xC1)), "erc1155 from");
        assertEq(result.erc1155[0].to, address(uint160(0xC2)), "erc1155 to");
        assertEq(result.erc1155[0].id, 0xC3C3, "erc1155 id");
        assertEq(result.erc1155[0].amount, 0xC4C4, "erc1155 amount");
    }

    /// `IFlowV5.stackToFlow` MAY revert if the stack is malformed. The
    /// observable revert is `MissingSentinel(RAIN_FLOW_SENTINEL)` from
    /// `LibStackSentinel.consumeSentinelTuples` when any of the three
    /// required sentinels is absent.
    function testStackToFlowRevertsOnEmptyStack() external {
        (IFlowV5 flow,) = deployFlow();
        uint256[] memory stack = new uint256[](0);
        vm.expectRevert(abi.encodeWithSelector(MissingSentinel.selector, RAIN_FLOW_SENTINEL));
        flow.stackToFlow(stack);
    }

    function testStackToFlowRevertsOnOneSentinelOnly() external {
        (IFlowV5 flow,) = deployFlow();
        uint256[] memory stack = new uint256[](1);
        stack[0] = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        vm.expectRevert(abi.encodeWithSelector(MissingSentinel.selector, RAIN_FLOW_SENTINEL));
        flow.stackToFlow(stack);
    }

    function testStackToFlowRevertsOnTwoSentinelsOnly() external {
        (IFlowV5 flow,) = deployFlow();
        uint256[] memory stack = new uint256[](2);
        stack[0] = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        stack[1] = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        vm.expectRevert(abi.encodeWithSelector(MissingSentinel.selector, RAIN_FLOW_SENTINEL));
        flow.stackToFlow(stack);
    }

    /// A stack whose top section is not aligned to the ERC20 tuple size (4).
    /// `consumeSentinelTuples` walks the cursor down from the top of the stack
    /// in strides of `4 * 0x20` bytes, testing the word below each stride for
    /// the sentinel. Here three plain words sit above the intended ERC20
    /// sentinel, so the stride never lands on the intended sentinel: the ERC20
    /// pass instead matches the ERC721 sentinel one stride lower and consumes
    /// it, the ERC721 pass then matches the ERC1155 sentinel and consumes it,
    /// and the ERC1155 pass finds no sentinel left below it. The parse reverts
    /// with `MissingSentinel(RAIN_FLOW_SENTINEL)` rather than mis-parsing the
    /// misaligned stack into a `FlowTransferV1`.
    function testStackToFlowRevertsOnMalformedTupleCount() external {
        (IFlowV5 flow,) = deployFlow();
        uint256 sentinel = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        uint256[] memory stack = new uint256[](6);
        stack[0] = sentinel; // erc1155 sentinel
        stack[1] = sentinel; // erc721 sentinel
        stack[2] = sentinel; // erc20 sentinel
        // Three trailing words above the ERC20 sentinel; 3 is not a multiple of
        // the ERC20 tuple size 4, so the section is misaligned.
        stack[3] = 1;
        stack[4] = 2;
        stack[5] = 3;
        vm.expectRevert(abi.encodeWithSelector(MissingSentinel.selector, RAIN_FLOW_SENTINEL));
        flow.stackToFlow(stack);
    }

    /// A `RAIN_FLOW_SENTINEL` planted inside a tuple field is indistinguishable
    /// from a real section boundary to `consumeSentinelTuples`, which scans for
    /// the first matching word from the top of the stack down. The planted
    /// sentinel in the top word is matched by the ERC20 pass as the ERC20
    /// boundary, so the ERC20 section is read as empty and the genuine ERC20
    /// sentinel lower in the stack is then matched by the ERC721 pass. The
    /// genuine ERC20 tuple is therefore consumed as an ERC721 tuple whose
    /// `token` field is the (truncated) sentinel value. `stackToFlow` does not
    /// revert: it returns a `FlowTransferV1` with the sections shifted and
    /// corrupted.
    function testStackToFlowSentinelInsideTupleCorrupts() external {
        (IFlowV5 flow,) = deployFlow();
        uint256 sentinel = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        // Stack layout (low index = bottom of stack, high index = top; top is
        // consumed first by stackToFlow):
        //   stack[0] sentinel (erc1155 boundary)
        //   stack[1] sentinel (erc721 boundary)
        //   stack[2] sentinel (intended erc20 boundary)
        //   stack[3..5] a (token, from, to) triple
        //   stack[6] sentinel planted where the erc20 `amount` field would be
        uint256[] memory stack = new uint256[](7);
        stack[0] = sentinel;
        stack[1] = sentinel;
        stack[2] = sentinel;
        stack[3] = uint256(uint160(address(0xAAAA)));
        stack[4] = uint256(uint160(address(this)));
        stack[5] = uint256(uint160(address(0xBBBB)));
        stack[6] = sentinel;

        FlowTransferV1 memory result = flow.stackToFlow(stack);

        // The planted sentinel is read as the erc20 boundary, so the erc20
        // section is empty.
        assertEq(result.erc20.length, 0, "erc20 section shifted away by planted sentinel");

        // The intended erc20 sentinel is consumed as the erc721 boundary, so
        // the (token, from, to) triple plus the intended erc20 sentinel are
        // read as a single erc721 tuple. The intended erc20 sentinel becomes
        // the erc721 `token` field, truncated to an address.
        assertEq(result.erc721.length, 1, "intended erc20 tuple misread as erc721");
        assertEq(result.erc721[0].token, address(uint160(sentinel)), "erc721 token is the truncated sentinel");
        assertEq(result.erc721[0].from, address(0xAAAA), "erc721 from");
        assertEq(result.erc721[0].to, address(this), "erc721 to");
        assertEq(result.erc721[0].id, uint256(uint160(address(0xBBBB))), "erc721 id");

        // Only the bottom sentinel remains for the erc1155 pass, so its section
        // is empty.
        assertEq(result.erc1155.length, 0, "erc1155 section empty");
    }
}
