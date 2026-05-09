// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {
    IFlowV5,
    FlowTransferV1,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    RAIN_FLOW_SENTINEL,
    Sentinel
} from "src/interface/IFlowV5.sol";
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
}
