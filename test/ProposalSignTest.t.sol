// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProposalSign} from "../src/proposal/ProposalSign.sol";

contract ProposalSignTest is Test {
    ProposalSign internal ps;

    address internal alice = address(0xA11CE);
    address internal bob   = address(0xB0B);

    function setUp() public {
        ps = new ProposalSign();
    }

    // ============================================================
    // proposeOrgNameChange
    // ============================================================

    function test_ProposeOrgNameChange_Success() public {
        vm.prank(alice);
        bool ok = ps.proposeOrgNameChange("New DAO Name");
        assertTrue(ok, "should return true");

        bytes32 hash = ps.indexOfUnsignedProposals(0);
        assertTrue(hash != bytes32(0));

        // ✅ 用 getSignatureInfo 拿完整 struct
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

        bytes32 hash = ps.indexOfUnsignedProposals(0);
        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.infos[0], "First", "old data should not be overwritten");

        // 数组仍只有 1 条：读 index 1 越界 revert
        vm.expectRevert();
        ps.indexOfUnsignedProposals(1);
    }

    function test_ProposeOrgNameChange_DifferentUsers() public {
        vm.prank(alice);
        ps.proposeOrgNameChange("Alice Proposal");

        vm.prank(bob);
        ps.proposeOrgNameChange("Bob Proposal");

        bytes32 h0 = ps.indexOfUnsignedProposals(0);
        bytes32 h1 = ps.indexOfUnsignedProposals(1);
        assertTrue(h0 != h1, "hashes should differ per applicant");

        ProposalSign.SignatureInfo memory i0 = ps.getSignatureInfo(h0);
        ProposalSign.SignatureInfo memory i1 = ps.getSignatureInfo(h1);
        assertEq(i0.applicant, alice);
        assertEq(i0.infos[0], "Alice Proposal");
        assertEq(i1.applicant, bob);
        assertEq(i1.infos[0], "Bob Proposal");

        vm.expectRevert();
        ps.indexOfUnsignedProposals(2);
    }

    function test_ProposeOrgNameChange_EmptyString() public {
        vm.prank(alice);
        assertTrue(ps.proposeOrgNameChange(""));

        bytes32 hash = ps.indexOfUnsignedProposals(0);
        ProposalSign.SignatureInfo memory info = ps.getSignatureInfo(hash);
        assertEq(info.infos.length, 1);
        assertEq(info.infos[0], "");
    }

    // ============================================================
    // allProposals
    // ============================================================

    function test_AllProposals_Empty() public view {
        ProposalSign.SignatureInfo[] memory list = ps.allProposals();
        assertEq(list.length, 0);
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
        assertEq(uint8(list[0].proposal), uint8(ProposalSign.Proposal.ORG_NAME_CHANG));

        assertEq(list[1].applicant, bob);
        assertEq(list[1].infos[0], "Bob DAO");
    }

    // ============================================================
    // membership
    // ============================================================

    function test_AddMember() public {
        ps.addMember(alice);
        address[] memory members = ps.allMembers();
        assertEq(members.length, 1);
        assertEq(members[0], alice);
    }

    function test_AddMember_Multiple() public {
        ps.addMember(alice);
        ps.addMember(bob);
        address[] memory members = ps.allMembers();
        assertEq(members.length, 2);
        assertEq(members[0], alice);
        assertEq(members[1], bob);
    }

    function test_RemoveMember() public {
        ps.addMember(alice);
        ps.addMember(bob);
        assertEq(ps.allMembers().length, 2);

        ps.removeMember(alice);
        address[] memory members = ps.allMembers();
        assertEq(members.length, 1);
        assertEq(members[0], bob);
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

        assertTrue(ps.indexOfUnsignedProposals(0) != ps.indexOfUnsignedProposals(1));
    }
}