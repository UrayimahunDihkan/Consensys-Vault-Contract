// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProposalSign} from "../src/proposal/ProposalSign.sol";

contract ProposalSignTransferTest is Test {
    ProposalSign public proposalSign;

    address internal alice = address(0xA11CE);
    address internal bob   = address(0xB0B);
    address internal carol = address(0xCA401);

    address internal mockRecipient = address(0x1111);
    address internal mockCurrency  = address(0x2222); // 测试用随便一个代币地址

    address[] internal initialSigners;

    function setUp() public {
        initialSigners = new address[](3);
        initialSigners[0] = alice;
        initialSigners[1] = bob;
        initialSigners[2] = carol;

        proposalSign = new ProposalSign(initialSigners);
    }

    // ============================================================
    // 1. 入参校验
    // ============================================================
    function test_ProposeTransfer_Revert_ZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert("address can not be empty");
        proposalSign.proposeTransfer(address(0), mockCurrency, 100);
    }

    function test_ProposeTransfer_Revert_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("amount should more than 0");
        proposalSign.proposeTransfer(mockRecipient, mockCurrency, 0);
    }

    // ============================================================
    // 2. 成功创建提案
    // ============================================================
    function test_ProposeTransfer_Success() public {
        vm.prank(alice);
        bool success = proposalSign.proposeTransfer(mockRecipient, mockCurrency, 1000);
        assertTrue(success);

        // 验证 allProposals 返回的数据
        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props.length, 1);

        ProposalSign.SignatureInfo memory info = props[0];

        // 验证基础字段
        assertEq(info.applicant, alice);
        assertEq(uint8(info.proposal), uint8(ProposalSign.Proposal.TRANSFER));
        assertEq(uint8(info.execFlow), uint8(ProposalSign.ExecFlow.PendingSign));
        assertEq(info.signatures.length, 0);

        // 验证转账专属字段
        assertEq(info.transferTo, mockRecipient);
        assertEq(info.transferCurrency, mockCurrency);
        assertEq(info.transferAmount, 1000);
    }

    // ============================================================
    // 3. Hash 冲突测试
    // ============================================================
    function test_ProposeTransfer_Duplicate_RevertsOrReturnsFalse() public {
        vm.startPrank(alice);
        assertTrue(proposalSign.proposeTransfer(mockRecipient, mockCurrency, 1000));

        // Bob 再次发起，因为 signers 没变，hash 相同，且未执行，返回 false
        vm.stopPrank();
        vm.prank(bob);
        assertFalse(proposalSign.proposeTransfer(mockRecipient, mockCurrency, 2000));
    }

    function test_ProposeTransfer_AfterExecuted_CanProposeAgain() public {
        // 1. alice 发起转账
        vm.prank(alice);
        proposalSign.proposeTransfer(mockRecipient, mockCurrency, 1000);

        // 2. 收集签名
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.TRANSFER);
        vm.prank(carol);
        proposalSign.signProposal(ProposalSign.Proposal.TRANSFER);

        // 3. 标记执行成功
        proposalSign.markAfterExecuted(ProposalSign.Proposal.TRANSFER);

        // 4. 此时状态是 Executed，alice 再次发起同类型提案应该成功
        vm.prank(alice);
        bool success = proposalSign.proposeTransfer(mockRecipient, mockCurrency, 500);
        assertTrue(success, "Should be able to propose again after executed");

        // 验证新的提案内容覆盖了旧的
        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props.length, 1); // 因为旧的被 markAfterExecuted 清除了数组，新的又被推了进去
        assertEq(props[0].transferAmount, 500);
    }
}