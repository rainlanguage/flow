// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    FlowTransferV1,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    RAIN_FLOW_SENTINEL
} from "src/interface/IFlowV5.sol";
import {REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

abstract contract FlowTransferOperation is Test {
    address constant TOKEN_A = address(uint160(uint256(keccak256("tokenA.test"))));
    address internal immutable TOKEN_B = address(uint160(uint256(keccak256("tokenB.test"))));
    address internal immutable TOKEN_C = address(uint160(uint256(keccak256("tokenC.test"))));

    constructor() {
        vm.pauseGasMetering();
        vm.etch(TOKEN_A, REVERTING_MOCK_BYTECODE);
        vm.etch(TOKEN_B, REVERTING_MOCK_BYTECODE);
        vm.etch(TOKEN_C, REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function transferEmpty() internal pure returns (FlowTransferV1 memory) {
        return FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0));
    }

    /// Builds a `FlowTransferV1` whose first ERC20 transfer has an
    /// unauthorized `from` (neither the flow contract nor the caller) and
    /// whose second is a valid self-flow. Used to test the
    /// `UnsupportedERC20Flow` revert path on a multi-transfer batch.
    //forge-lint: disable-next-line(mixed-case-function)
    function unauthorizedERC20Flow(address unauthorized, address authorized, address flow, uint256 amount)
        internal
        view
        returns (FlowTransferV1 memory)
    {
        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] = ERC20Transfer({token: TOKEN_A, from: unauthorized, to: flow, amount: amount});
        erc20Transfers[1] = ERC20Transfer({token: TOKEN_B, from: flow, to: authorized, amount: amount});
        return FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0));
    }

    /// Same shape as `unauthorizedERC20Flow` but for ERC721.
    //forge-lint: disable-next-line(mixed-case-function)
    function unauthorizedERC721Flow(address unauthorized, address authorized, address flow, uint256 tokenId)
        internal
        view
        returns (FlowTransferV1 memory)
    {
        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] = ERC721Transfer({token: TOKEN_A, from: unauthorized, to: flow, id: tokenId});
        erc721Transfers[1] = ERC721Transfer({token: TOKEN_B, from: flow, to: authorized, id: tokenId});
        return FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0));
    }

    /// Same shape as `unauthorizedERC20Flow` but for ERC1155.
    //forge-lint: disable-next-line(mixed-case-function)
    function unauthorizedERC1155Flow(
        address unauthorized,
        address authorized,
        address flow,
        uint256 outId,
        uint256 outAmount,
        uint256 inId,
        uint256 inAmount
    ) internal view returns (FlowTransferV1 memory) {
        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
        erc1155Transfers[0] =
            ERC1155Transfer({token: TOKEN_A, from: unauthorized, to: flow, id: outId, amount: outAmount});
        erc1155Transfers[1] =
            ERC1155Transfer({token: TOKEN_B, from: flow, to: authorized, id: inId, amount: inAmount});
        return FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function transferERC721ToERC1155(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155OutTokenId
    ) internal returns (FlowTransferV1 memory transfer) {
        transfer = createTransferERC721ToERC1155(
            addressA, addressB, erc721InTokenId, erc1155OutAmount, erc1155OutTokenId
        );
        mockTransferERC721ToERC1155(addressA, addressB, erc721InTokenId, erc1155OutAmount, erc1155OutTokenId);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function createTransferERC721ToERC1155(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155OutTokenId
    ) internal view returns (FlowTransferV1 memory) {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721InTokenId);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutTokenId);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] = ERC721Transfer({token: TOKEN_B, from: addressA, to: addressB, id: erc721InTokenId});

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
        erc1155Transfers[0] = ERC1155Transfer({
            token: TOKEN_C, from: addressB, to: addressA, id: erc1155OutTokenId, amount: erc1155OutAmount
        });

        return FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, erc1155Transfers);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function mockTransferERC721ToERC1155(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155OutTokenId
    ) internal {
        vm.mockCall(TOKEN_B, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            TOKEN_B,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressA, addressB, erc721InTokenId
            )
        );

        vm.mockCall(TOKEN_C, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            TOKEN_C,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, addressB, addressA, erc1155OutTokenId, erc1155OutAmount, ""
            )
        );
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function transferERC20ToERC721(address addressA, address addressB, uint256 erc20InAmount, uint256 erc721OutTokenId)
        internal
        returns (FlowTransferV1 memory transfer)
    {
        transfer = createTransferERC20ToERC721(addressA, addressB, erc20InAmount, erc721OutTokenId);
        mockTransferERC20ToERC721(addressA, addressB, erc20InAmount, erc721OutTokenId);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function createTransferERC20ToERC721(
        address addressA,
        address addressB,
        uint256 erc20InAmount,
        uint256 erc721OutTokenId
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20InAmount);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721OutTokenId);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
            erc20Transfers[0] = ERC20Transfer({token: TOKEN_A, from: addressA, to: addressB, amount: erc20InAmount});

            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] = ERC721Transfer({token: TOKEN_B, from: addressB, to: addressA, id: erc721OutTokenId});

            transfer = FlowTransferV1(erc20Transfers, erc721Transfers, new ERC1155Transfer[](0));
        }
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function mockTransferERC20ToERC721(
        address addressA,
        address addressB,
        uint256 erc20InAmount,
        uint256 erc721OutTokenId
    ) internal {
        vm.mockCall(TOKEN_A, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(TOKEN_A, abi.encodeWithSelector(IERC20.transferFrom.selector, addressA, addressB, erc20InAmount));

        vm.mockCall(TOKEN_B, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            TOKEN_B,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressB, addressA, erc721OutTokenId
            )
        );
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function transferERC721ToERC721(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc721OutTokenId
    ) internal returns (FlowTransferV1 memory transfer) {
        transfer = createTransferERC721ToERC721(addressA, addressB, erc721InTokenId, erc721OutTokenId);
        mockTransferERC721ToERC721(addressA, addressB, erc721InTokenId, erc721OutTokenId);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function createTransferERC721ToERC721(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc721OutTokenId
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721InTokenId);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721OutTokenId);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
            erc721Transfers[0] = ERC721Transfer({token: TOKEN_A, from: addressA, to: addressB, id: erc721InTokenId});
            erc721Transfers[1] = ERC721Transfer({token: TOKEN_B, from: addressB, to: addressA, id: erc721OutTokenId});
            transfer = FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0));
        }
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function mockTransferERC721ToERC721(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc721OutTokenId
    ) internal {
        vm.mockCall(TOKEN_A, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            TOKEN_A,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressA, addressB, erc721InTokenId
            )
        );

        vm.mockCall(TOKEN_B, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            TOKEN_B,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressB, addressA, erc721OutTokenId
            )
        );
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function transfersERC20toERC20(address addressA, address addressB, uint256 erc20BInAmount, uint256 erc20OutAmount)
        internal
        returns (FlowTransferV1 memory transfer)
    {
        transfer = createTransfersERC20toERC20(addressA, addressB, erc20BInAmount, erc20OutAmount);
        mockTransfersERC20toERC20(addressA, addressB, erc20BInAmount, erc20OutAmount);
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function createTransfersERC20toERC20(
        address addressA,
        address addressB,
        uint256 erc20BInAmount,
        uint256 erc20OutAmount
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20BInAmount);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20OutAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] = ERC20Transfer({token: TOKEN_A, from: addressA, to: addressB, amount: erc20BInAmount});
            erc20Transfers[1] = ERC20Transfer({token: TOKEN_B, from: addressB, to: addressA, amount: erc20OutAmount});
            transfer = FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0));
        }
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function mockTransfersERC20toERC20(
        address addressA,
        address addressB,
        uint256 erc20BInAmount,
        uint256 erc20OutAmount
    ) internal {
        vm.mockCall(TOKEN_A, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(TOKEN_A, abi.encodeWithSelector(IERC20.transferFrom.selector, addressA, addressB, erc20BInAmount));

        vm.mockCall(TOKEN_B, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(TOKEN_B, abi.encodeWithSelector(IERC20.transfer.selector, addressA, erc20OutAmount));
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function transferERC1155ToERC1155(
        address addressA,
        address addressB,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal returns (FlowTransferV1 memory transfer) {
        transfer = createTransferERC1155ToERC1155(
            addressA, addressB, erc1155BInTokenId, erc1155BInAmount, erc1155OutTokenId, erc1155OutAmount
        );
        MockTransferERC1155ToERC1155(
            addressA, addressB, erc1155BInTokenId, erc1155BInAmount, erc1155OutTokenId, erc1155OutAmount
        );
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function createTransferERC1155ToERC1155(
        address addressA,
        address addressB,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutTokenId);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutAmount);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155BInTokenId);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155BInAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);

            erc1155Transfers[0] = ERC1155Transfer({
                token: TOKEN_A, from: addressA, to: addressB, id: erc1155BInTokenId, amount: erc1155BInAmount
            });

            erc1155Transfers[1] = ERC1155Transfer({
                token: TOKEN_B, from: addressB, to: addressA, id: erc1155OutTokenId, amount: erc1155OutAmount
            });

            transfer = FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers);
        }
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function MockTransferERC1155ToERC1155(
        address addressA,
        address addressB,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal {
        {
            vm.mockCall(TOKEN_A, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
            vm.expectCall(
                TOKEN_A,
                abi.encodeWithSelector(
                    IERC1155.safeTransferFrom.selector, addressA, addressB, erc1155BInTokenId, erc1155BInAmount, ""
                )
            );

            vm.mockCall(TOKEN_B, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
            vm.expectCall(
                TOKEN_B,
                abi.encodeWithSelector(
                    IERC1155.safeTransferFrom.selector, addressB, addressA, erc1155OutTokenId, erc1155OutAmount, ""
                )
            );
        }
    }

    function multiTransfersERC20(address addressA, address addressB, uint256 erc20AmountA, uint256 erc20AmountB)
        internal
        view
        returns (FlowTransferV1 memory transfer)
    {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20AmountA);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20AmountB);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](4);
            erc20Transfers[0] =
                ERC20Transfer({token: TOKEN_A, from: address(addressB), to: addressA, amount: erc20AmountA});
            erc20Transfers[1] =
                ERC20Transfer({token: TOKEN_B, from: address(addressB), to: addressA, amount: erc20AmountB});
            erc20Transfers[2] =
                ERC20Transfer({token: TOKEN_A, from: addressA, to: address(addressB), amount: erc20AmountA});
            erc20Transfers[3] =
                ERC20Transfer({token: TOKEN_B, from: addressA, to: address(addressB), amount: erc20AmountB});
            transfer = FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0));
        }
    }

    function multiTransferERC721(address addressA, address addressB, uint256 erc721TokenIdA, uint256 erc721TokenIdB)
        internal
        view
        returns (FlowTransferV1 memory transfer)
    {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721TokenIdA);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721TokenIdB);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](4);
            erc721Transfers[0] = ERC721Transfer({token: TOKEN_A, from: addressB, to: addressA, id: erc721TokenIdA});
            erc721Transfers[1] = ERC721Transfer({token: TOKEN_B, from: addressB, to: addressA, id: erc721TokenIdB});
            erc721Transfers[2] = ERC721Transfer({token: TOKEN_A, from: addressA, to: addressB, id: erc721TokenIdA});
            erc721Transfers[3] = ERC721Transfer({token: TOKEN_B, from: addressA, to: addressB, id: erc721TokenIdB});
            transfer = FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0));
        }
    }

    function multiTransferERC1155(
        address addressA,
        address addressB,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutTokenId);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutAmount);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155InTokenId);
            vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155InAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](4);

            erc1155Transfers[0] = ERC1155Transfer({
                token: TOKEN_A, from: addressB, to: addressA, id: erc1155OutTokenId, amount: erc1155OutAmount
            });

            erc1155Transfers[1] = ERC1155Transfer({
                token: TOKEN_B, from: addressB, to: addressA, id: erc1155InTokenId, amount: erc1155InAmount
            });

            erc1155Transfers[2] = ERC1155Transfer({
                token: TOKEN_A, from: addressA, to: addressB, id: erc1155OutTokenId, amount: erc1155OutAmount
            });

            erc1155Transfers[3] = ERC1155Transfer({
                token: TOKEN_B, from: addressA, to: addressB, id: erc1155InTokenId, amount: erc1155InAmount
            });

            transfer = FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers);
        }
    }

    function assumeAddressNotSentinel(address inputAddress) internal pure {
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != uint256(uint160(inputAddress)));
    }
}
