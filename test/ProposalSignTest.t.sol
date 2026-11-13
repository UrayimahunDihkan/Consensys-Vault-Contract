// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProposalSign} from "../src/proposal/ProposalSign.sol";
import {console} from "forge-std/console.sol";


contract ProposalSignTest is Test {
    ProposalSign internal ps;

    // Anvil 默认账号
    address internal alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal bob   = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal carol = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal dave  = address(0xD4AE); // 不在初始 signers 里

    address[] internal initialSigners;

    function setUp() public {
        initialSigners = new address[](3);
        initialSigners[0] = alice;
        initialSigners[1] = bob;
        initialSigners[2] = carol;

        ps = new ProposalSign(initialSigners);
    }

    // ============================================================
    // constructor
    // ============================================================

    function test_Constructor_AddsInitialSigners() public view {
        address[] memory members = ps.allMembers();
        assertEq(members.length, 3);
        assertEq(members[0], alice);
        assertEq(members[1], bob);
        assertEq(members[2], carol);
    }

    // ============================================================
    // proposeOrgNameChange
    // ============================================================

    function test_ProposeOrgNameChange_Success() public {
        vm.prank(alice);
        bool ok = ps.proposeOrgNameChange("New DAO Name");
        assertTrue(ok);

        bytes32 hash = ps.indexOfUnexecutedProposals(0);
        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);

        assertEq(info.applicant, alice);
        assertEq(info.signatures.length, 0);
        assertEq(uint8(info.proposal), uint8(ProposalSign.Proposal.ORG_NAME_CHANG));
        assertEq(info.infos.length, 1);
        assertEq(info.infos[0], "New DAO Name");
    }

    function test_ProposeOrgNameChange_Duplicate_ReturnsFalse() public {
        vm.startPrank(alice);
        assertTrue(ps.proposeOrgNameChange("First"));
        assertFalse(ps.proposeOrgNameChange("Second"));
        vm.stopPrank();

        bytes32 hash = ps.indexOfUnexecutedProposals(0);
        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.infos[0], "First", "old data should not be overwritten");

        vm.expectRevert();
        ps.indexOfUnexecutedProposals(1);
    }

    function test_ProposeOrgNameChange_DifferentUsers() public {
        vm.prank(alice);
        ps.proposeOrgNameChange("Alice Proposal");
        vm.prank(bob);
        ps.proposeOrgNameChange("Bob Proposal");

        bytes32 h0 = ps.indexOfUnexecutedProposals(0);
        bytes32 h1 = ps.indexOfUnexecutedProposals(1);
        assertTrue(h0 != h1);

        ProposalSign.SignatureInfo memory i0 = ps.getSignatureInfo(h0);
        ProposalSign.SignatureInfo memory i1 = ps.getSignatureInfo(h1);
        assertEq(i0.applicant, alice);
        assertEq(i0.infos[0], "Alice Proposal");
        assertEq(i1.applicant, bob);
        assertEq(i1.infos[0], "Bob Proposal");
    }

    function test_ProposeOrgNameChange_EmptyString() public {
        vm.prank(alice);
        assertTrue(ps.proposeOrgNameChange(""));

        bytes32 hash = ps.indexOfUnexecutedProposals(0);
        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.infos.length, 1);
        assertEq(info.infos[0], "");
    }

    // ============================================================
    // allProposals
    // ============================================================

    function test_AllProposals_Empty() public view {
        assertEq(ps.allProposals().length, 0);
    }

    function test_AllProposals_Multiple() public {
        vm.prank(alice);
        ps.proposeOrgNameChange("Alice DAO");
        vm.prank(bob);
        ps.proposeOrgNameChange("Bob DAO");

        ProposalSign.SignatureInfo[] memory list = ps.allProposals();
        assertEq(list.length, 2);
        assertEq(list[0].applicant, alice);
        assertEq(list[0].infos[0], "Alice DAO");
        assertEq(list[1].applicant, bob);
        assertEq(list[1].infos[0], "Bob DAO");
    }

    // ============================================================
    // signProposal
    // ============================================================

    function test_SignProposal_Success() public {
        vm.prank(alice);
        ps.proposeOrgNameChange("X");
        bytes32 hash = ps.indexOfUnexecutedProposals(0);

        vm.prank(bob);
        assertTrue(ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG));

        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.signatures.length, 1);
        assertEq(info.signatures[0], bob);
    }

    function test_SignProposal_MultipleSigners() public {
        vm.prank(alice);
        ps.proposeOrgNameChange("X");
        bytes32 hash = ps.indexOfUnexecutedProposals(0);

        vm.prank(bob);
        ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
        vm.prank(carol);
        ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.signatures.length, 2);
        assertEq(info.signatures[0], bob);
        assertEq(info.signatures[1], carol);
    }

    function test_SignProposal_NonExistent_Reverts() public {
        vm.prank(bob);
        vm.expectRevert("This proposal doesn't exist");
        ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
    }

    function test_SignProposal_WrongEnum_Reverts() public {
        // alice 发起 ORG_NAME_CHANG
        vm.prank(alice);
        ps.proposeOrgNameChange("X");

        // bob 用 TRANSFER 签 -> hash 不同 -> revert
        vm.prank(bob);
        vm.expectRevert("This proposal doesn't exist");
        ps.signProposal(ProposalSign.Proposal.TRANSFER);
    }

    function test_SignProposal_NonSigner_StillAllowed() public {
        // 当前合约没检查 signer 身份，dave 也能签（固定现状）
        vm.prank(alice);
        ps.proposeOrgNameChange("X");
        bytes32 hash = ps.indexOfUnexecutedProposals(0);

        vm.prank(dave);
        ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.signatures.length, 1);
        assertEq(info.signatures[0], dave);
    }

    function test_SignProposal_DuplicateSigner_Allowed() public {
        // 当前合约没防重复签名，同一人签两次会 push 两次
        vm.prank(alice);
        ps.proposeOrgNameChange("X");
        bytes32 hash = ps.indexOfUnexecutedProposals(0);

        vm.startPrank(bob);
        ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
        ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
        vm.stopPrank();

        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.signatures.length, 2);
        assertEq(info.signatures[0], bob);
        assertEq(info.signatures[1], bob);
    }

    // ============================================================
    // membership
    // ============================================================

    function test_AddMember() public {
        ps.addMember(dave);
        address[] memory members = ps.allMembers();
        assertEq(members.length, 4);
        assertEq(members[3], dave);
    }

    function test_RemoveMember() public {
        ps.removeMember(alice);
        address[] memory members = ps.allMembers();
        console.log("members.length =", members.length);
        for (uint256 i = 0; i < members.length; i++) {
            console.log("members[%d] =", i, members[i]);
        }
        assertEq(members.length, 2);
        assertEq(members[0], bob);
        assertEq(members[1], carol);
    }

    // ============================================================
    // hash 稳定性
    // ============================================================

    function test_HashStability_SameInputSameHash() public {
        vm.startPrank(alice);
        assertTrue(ps.proposeOrgNameChange("A"));
        assertFalse(ps.proposeOrgNameChange("B"));
        vm.stopPrank();
    }

    function test_HashDifferentPerUser() public {
        vm.prank(alice);
        ps.proposeOrgNameChange("X");
        vm.prank(bob);
        ps.proposeOrgNameChange("X");

        assertTrue(ps.indexOfUnexecutedProposals(0) != ps.indexOfUnexecutedProposals(1));
    }

    function test_HashDifferentPerEnum() public {
        vm.prank(alice);
        ps.proposeOrgNameChange("X");

        // 用 TRANSFER 签 -> 不同 hash -> revert
        vm.prank(alice);
        vm.expectRevert("This proposal doesn't exist");
        ps.signProposal(ProposalSign.Proposal.TRANSFER);

        // 用 ORG_NAME_CHANG 签 -> 成功
        vm.prank(alice);
        assertTrue(ps.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG));
    }
}