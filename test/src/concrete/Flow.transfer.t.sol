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
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {
    UnsupportedERC20Flow,
    UnsupportedERC721Flow,
    UnsupportedERC1155Flow,
    UnregisteredFlow
} from "src/error/ErrFlow.sol";

import {FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS} from "src/concrete/Flow.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {MaliciousReenteringStore} from "test/concrete/MaliciousReenteringStore.sol";
import {MaliciousReenteringRecipient} from "test/concrete/MaliciousReenteringRecipient.sol";
import {StubERC721WithReceiverHook} from "test/concrete/StubERC721WithReceiverHook.sol";
import {StubERC1155WithReceiverHook} from "test/concrete/StubERC1155WithReceiverHook.sol";

/// `IERC721.safeTransferFrom` is overloaded (3-arg + 4-arg). Pin the 3-arg
/// selector via a single-overload wrapper interface so the disambiguation
/// is done by the compiler rather than by hand-hashing the signature.
interface IERC721SafeTransferFromV3 {
    //forge-lint: disable-next-line(mixed-case-function)
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

bytes4 constant ERC721_SAFE_TRANSFER_FROM_3 = IERC721SafeTransferFromV3.safeTransferFrom.selector;

contract FlowTransferTest is FlowTest {
    using LibEvaluable for EvaluableV2;

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) external {
        vm.assume(address(0) != alice);
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC721ToERC1155(alice, address(flow), erc721InTokenId, erc1155OutAmount, erc1155OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20ToERC721(address alice, uint256 erc20InAmount, uint256 erc721OutTokenId) external {
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC20ToERC721(alice, address(flow), erc20InAmount, erc721OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155ToERC1155(address alice, uint256 erc1155TokenId, uint256 erc1155Amount) external {
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC1155ToERC1155(
                    alice, address(flow), erc1155TokenId, erc1155Amount, erc1155TokenId, erc1155Amount
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721ToERC721(address alice, uint256 erc721OutTokenId, uint256 erc721InTokenId) external {
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721OutTokenId);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721InTokenId);
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC721ToERC721(alice, address(flow), erc721InTokenId, erc721OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20ToERC20(address alice, uint256 erc20OutAmount, uint256 erc20InAmount) external {
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice, 20 ether, 10 ether, 5, transfersERC20toERC20(alice, address(flow), erc20InAmount, erc20OutAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowShouldErrorIfERC20FlowFromIsOtherThanSourceContractOrMsgSender(
        address alice,
        address bob,
        uint256 erc20Amount
    ) external {
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20Amount);
        vm.assume(bob != alice);
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));
        assumeEtchable(bob, address(flow));

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] = ERC20Transfer({token: TOKEN_A, from: bob, to: address(flow), amount: erc20Amount});
            erc20Transfers[1] = ERC20Transfer({token: TOKEN_B, from: address(flow), to: alice, amount: erc20Amount});

            uint256[] memory stack = LibStackGeneration.generateFlowStack(
                Sentinel.unwrap(RAIN_FLOW_SENTINEL),
                FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
            );

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC20Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] = ERC20Transfer({token: TOKEN_A, from: alice, to: address(flow), amount: erc20Amount});
            erc20Transfers[1] = ERC20Transfer({token: TOKEN_B, from: bob, to: alice, amount: erc20Amount});
            vm.mockCall(TOKEN_A, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

            uint256[] memory stack = LibStackGeneration.generateFlowStack(
                Sentinel.unwrap(RAIN_FLOW_SENTINEL),
                FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
            );

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC20Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowShouldErrorIfERC721FlowFromIsOtherThanSourceContractOrMsgSender(
        address alice,
        address bob,
        uint256 erc721TokenId
    ) external {
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721TokenId);
        vm.assume(bob != alice);

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));
        assumeEtchable(bob, address(flow));

        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
            erc721Transfers[0] = ERC721Transfer({token: TOKEN_A, from: bob, to: address(flow), id: erc721TokenId});
            erc721Transfers[1] = ERC721Transfer({token: TOKEN_B, from: address(flow), to: alice, id: erc721TokenId});

            uint256[] memory stack = LibStackGeneration.generateFlowStack(
                Sentinel.unwrap(RAIN_FLOW_SENTINEL),
                FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
            );

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC721Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowShouldErrorIfERC1155FlowFromIsOtherThanSourceContractOrMsgSender(
        address alice,
        address bob,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount
    ) external {
        vm.assume(bob != alice);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutTokenId);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155OutAmount);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155InTokenId);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155InAmount);
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        assumeEtchable(alice, address(flow));
        assumeEtchable(bob, address(flow));

        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
            erc1155Transfers[0] = ERC1155Transfer({
                token: TOKEN_A, from: bob, to: address(flow), id: erc1155OutTokenId, amount: erc1155OutAmount
            });

            erc1155Transfers[1] = ERC1155Transfer({
                token: TOKEN_B, from: address(flow), to: alice, id: erc1155InTokenId, amount: erc1155InAmount
            });

            uint256[] memory stack = LibStackGeneration.generateFlowStack(
                Sentinel.unwrap(RAIN_FLOW_SENTINEL),
                FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
            );

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC1155Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testShouldErrorIfFlowBeingEvaluatedIsUnregistered(address alice, address expressionA, address expressionB)
        external
    {
        vm.assume(alice != address(0));
        vm.assume(expressionA != expressionB);
        assumeEtchable(alice);

        vm.label(alice, "Alice");

        address[] memory expressionsA = new address[](1);
        expressionsA[0] = expressionA;

        (, EvaluableV2[] memory evaluables) = deployFlow(expressionsA, new uint256[][](1));

        address[] memory expressionsB = new address[](1);
        expressionsB[0] = expressionB;

        (IFlowV5 flowB,) = deployFlow(expressionsB, new uint256[][](1));
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(UnregisteredFlow.selector, evaluables[0].hash()));
        flowB.flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests that the flow halts if it does not meet the 'ensure' requirement.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowHaltIfEnsureRequirementNotMet() external {
        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(address(0), address(flow));

        (uint256[] memory stack,) = mintAndBurnFlowStack(address(this), 20 ether, 10 ether, 5, transferEmpty());
        interpreterEval2MockCall(stack, new uint256[](0));

        uint256[][] memory context = LibContextWrapper.buildAndSetContext(
            new uint256[](0), new SignedContextV1[](0), address(this), address(flow)
        );

        interpreterEval2RevertCall(
            address(flow), LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS), context
        );

        vm.expectRevert("REVERT_EVAL2_CALL");
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
    }

    /// Pins the execution order ERC20 → ERC721 → ERC1155 against the upstream
    /// invariant in `IFlowV5` and `LibFlow.flow`. If ERC20 reverts, neither
    /// ERC721 nor ERC1155 must be called — this proves ERC20 is processed
    /// before the other two types.
    /// forge-config: default.fuzz.runs = 100
    function testFlowProcessesERC20BeforeERC721AndERC1155(
        address alice,
        uint256 erc20Amount,
        uint256 erc721Id,
        uint256 erc1155Id,
        uint256 erc1155Amount
    ) external {
        vm.assume(alice != address(0));
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20Amount);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721Id);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155Id);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155Amount);
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
        erc20Transfers[0] = ERC20Transfer({token: TOKEN_A, from: alice, to: address(flow), amount: erc20Amount});
        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] = ERC721Transfer({token: TOKEN_B, from: alice, to: address(flow), id: erc721Id});
        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
        erc1155Transfers[0] =
            ERC1155Transfer({token: TOKEN_C, from: alice, to: address(flow), id: erc1155Id, amount: erc1155Amount});
        FlowTransferV1 memory transfer = FlowTransferV1(erc20Transfers, erc721Transfers, erc1155Transfers);

        uint256[] memory stack = LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transfer);
        interpreterEval2MockCall(stack, new uint256[](0));

        // ERC20 reverts. ERC721 and ERC1155 mocks must NEVER fire because the
        // ERC20 revert propagates and stops the flow before reaching them.
        vm.mockCallRevert(TOKEN_A, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode("erc20-fail"));
        vm.expectCall(TOKEN_B, abi.encodeWithSelector(ERC721_SAFE_TRANSFER_FROM_3), 0);
        vm.expectCall(TOKEN_C, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), 0);

        vm.startPrank(alice);
        vm.expectRevert();
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// Pins the execution order ERC721 → ERC1155. With ERC20 mocked OK and
    /// ERC721 reverting, ERC1155 must never be reached.
    /// forge-config: default.fuzz.runs = 100
    function testFlowProcessesERC721BeforeERC1155(
        address alice,
        uint256 erc20Amount,
        uint256 erc721Id,
        uint256 erc1155Id,
        uint256 erc1155Amount
    ) external {
        vm.assume(alice != address(0));
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc20Amount);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc721Id);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155Id);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != erc1155Amount);
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
        erc20Transfers[0] = ERC20Transfer({token: TOKEN_A, from: alice, to: address(flow), amount: erc20Amount});
        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] = ERC721Transfer({token: TOKEN_B, from: alice, to: address(flow), id: erc721Id});
        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
        erc1155Transfers[0] =
            ERC1155Transfer({token: TOKEN_C, from: alice, to: address(flow), id: erc1155Id, amount: erc1155Amount});
        FlowTransferV1 memory transfer = FlowTransferV1(erc20Transfers, erc721Transfers, erc1155Transfers);

        uint256[] memory stack = LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transfer);
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.mockCall(TOKEN_A, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.mockCallRevert(TOKEN_B, abi.encodeWithSelector(ERC721_SAFE_TRANSFER_FROM_3), abi.encode("erc721-fail"));
        // ERC1155 must never be reached.
        vm.expectCall(TOKEN_C, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), 0);

        vm.startPrank(alice);
        vm.expectRevert();
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// `Flow.flow` carries `nonReentrant`. A malicious interpreter store
    /// whose `set` re-enters `flow.flow(...)` MUST cause the inner call
    /// to revert.
    function testFlowReentrancyGuardFiresOnStoreCallback(uint256 writeKey, uint256 writeValue) external {
        address alice = address(uint160(uint256(keccak256("alice.reentrancy.store"))));
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        // Replace the framework's mock STORE with the malicious bytecode so
        // LibFlow.flow's `set(...)` lands in the re-entering implementation.
        MaliciousReenteringStore malStore = new MaliciousReenteringStore(flow);
        malStore.setEvaluable(evaluable);
        vm.etch(address(STORE), address(malStore).code);
        // The runtime still needs to know which evaluable to flow into; the
        // MaliciousReenteringStore reads its `evaluable` storage slot, so
        // copy it over after the etch.
        bytes32 evalSlot0 = vm.load(address(malStore), bytes32(uint256(0)));
        bytes32 evalSlot1 = vm.load(address(malStore), bytes32(uint256(1)));
        bytes32 evalSlot2 = vm.load(address(malStore), bytes32(uint256(2)));
        vm.store(address(STORE), bytes32(uint256(0)), evalSlot0);
        vm.store(address(STORE), bytes32(uint256(1)), evalSlot1);
        vm.store(address(STORE), bytes32(uint256(2)), evalSlot2);

        // Eval2 returns non-empty kvs so LibFlow.flow takes the `set` branch.
        uint256[] memory stack =
            LibStackGeneration.generateFlowStack(Sentinel.unwrap(RAIN_FLOW_SENTINEL), transferEmpty());
        uint256[] memory writes = new uint256[](2);
        writes[0] = writeKey;
        writes[1] = writeValue;
        interpreterEval2MockCall(stack, writes);

        vm.startPrank(alice);
        vm.expectRevert(bytes("ReentrancyGuard: reentrant call"));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// A malicious ERC721 recipient whose `onERC721Received` re-enters
    /// `flow.flow(...)` MUST cause the inner call to revert. Exercises the
    /// EIP-721 receiver-hook reentrancy path (the underlying token's
    /// `safeTransferFrom` invokes the recipient hook on a contract `to`).
    /// forge-config: default.fuzz.runs = 100
    function testFlowReentrancyGuardFiresOnERC721Recipient(uint256 tokenId) external {
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != tokenId);
        address alice = address(uint160(uint256(keccak256("alice.reentrancy.erc721"))));
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        // Etch a stub ERC721 implementation at TOKEN_B that forwards
        // safeTransferFrom into the recipient hook.
        StubERC721WithReceiverHook stub = new StubERC721WithReceiverHook();
        vm.etch(TOKEN_B, address(stub).code);

        // Deploy the malicious recipient and arm it with the flow's
        // evaluable.
        MaliciousReenteringRecipient recipient = new MaliciousReenteringRecipient(flow);
        recipient.setEvaluable(evaluable);

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] = ERC721Transfer({token: TOKEN_B, from: address(flow), to: address(recipient), id: tokenId});

        uint256[] memory stack = LibStackGeneration.generateFlowStack(
            Sentinel.unwrap(RAIN_FLOW_SENTINEL),
            FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        vm.expectRevert(bytes("ReentrancyGuard: reentrant call"));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// A malicious ERC1155 recipient whose `onERC1155Received` re-enters
    /// `flow.flow(...)` MUST cause the inner call to revert. Exercises the
    /// EIP-1155 receiver-hook reentrancy path.
    /// forge-config: default.fuzz.runs = 100
    function testFlowReentrancyGuardFiresOnERC1155Recipient(uint256 tokenId, uint256 amount) external {
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != tokenId);
        vm.assume(Sentinel.unwrap(RAIN_FLOW_SENTINEL) != amount);
        address alice = address(uint160(uint256(keccak256("alice.reentrancy.erc1155"))));
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        StubERC1155WithReceiverHook stub = new StubERC1155WithReceiverHook();
        vm.etch(TOKEN_C, address(stub).code);

        MaliciousReenteringRecipient recipient = new MaliciousReenteringRecipient(flow);
        recipient.setEvaluable(evaluable);

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
        erc1155Transfers[0] =
            ERC1155Transfer({token: TOKEN_C, from: address(flow), to: address(recipient), id: tokenId, amount: amount});

        uint256[] memory stack = LibStackGeneration.generateFlowStack(
            Sentinel.unwrap(RAIN_FLOW_SENTINEL),
            FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        vm.expectRevert(bytes("ReentrancyGuard: reentrant call"));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }
}
