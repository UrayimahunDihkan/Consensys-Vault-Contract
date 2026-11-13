// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProposalSign} from "../src/proposal/ProposalSign.sol";
import {ConsensusWallet} from "../src/consensus-wallet/ConsensusWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ConsensusTest is Test {
    ProposalSign public proposalSign;
    ConsensusWallet public walletImpl;
    ConsensusWallet public walletProxy;

    address internal alice = address(0xA11CE);
    address internal bob   = address(0xB0B);
    address internal carol = address(0xCA401);
    address internal dave  = address(0xD4AE);

    address[] internal initialSigners;

    function setUp() public {
        initialSigners = new address[](3);
        initialSigners[0] = alice;
        initialSigners[1] = bob;
        initialSigners[2] = carol;

        // 1. 部署 ProposalSign
        proposalSign = new ProposalSign(initialSigners);

        // 2. 部署 ConsensusWallet Implementation
        walletImpl = new ConsensusWallet();

        // 3. 部署 Proxy，并调用 initialize
        bytes memory initData = abi.encodeWithSelector(
            ConsensusWallet.initialize.selector,
            "Original DAO Name",
            address(proposalSign)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(walletImpl), initData);
        walletProxy = ConsensusWallet(payable(address(proxy)));
    }

    // ============================================================
    // 初始化
    // ============================================================

    function test_Initialize() public view {
        assertEq(walletProxy.orgName(), "Original DAO Name");
        assertEq(walletProxy.proposalSignAddress(), address(proposalSign));
        assertEq(walletProxy.owner(), address(this));
    }

    function test_Revert_Initialize_Twice() public {
        vm.expectRevert();
        walletProxy.initialize("Another Name", address(0));
    }

    // ============================================================
    // ProposalSign：创建 / 签名 / 状态流转
    // ============================================================

    function test_ProposeOrgNameChange() public {
        vm.prank(alice);
        assertTrue(proposalSign.proposeOrgNameChange("New DAO Name"));

        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props.length, 1);
        assertEq(props[0].applicant, alice);
        assertEq(props[0].infos[0], "New DAO Name");
        assertEq(uint8(props[0].execFlow), uint8(ProposalSign.ExecFlow.PendingSign));
    }

    function test_ProposeOrgNameChange_Duplicate_ReturnsFalse() public {
        vm.startPrank(alice);
        assertTrue(proposalSign.proposeOrgNameChange("Name 1"));
        assertFalse(proposalSign.proposeOrgNameChange("Name 2"));
        vm.stopPrank();
    }

    function test_SignProposal_PartialAndComplete() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("New DAO Name");

        // 3 人阈值 = ceil(3/2) = 2
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props[0].signatures.length, 1);
        assertEq(uint8(props[0].execFlow), uint8(ProposalSign.ExecFlow.SignPartiallyCompleted));

        vm.prank(carol);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        props = proposalSign.allProposals();
        assertEq(props[0].signatures.length, 2);
        assertEq(uint8(props[0].execFlow), uint8(ProposalSign.ExecFlow.SignCompleted));
    }

    function test_SignProposal_NonExistent_Reverts() public {
        vm.prank(bob);
        vm.expectRevert("This proposal doesn't exist");
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
    }

    // ============================================================
    // ConsensusWallet + ProposalSign 跨合约执行
    // ============================================================

    function test_ExecuteSetOrgName_Success() public {
        // 1. 发起提案
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("Executed DAO Name");

        // 2. 收集签名（达标）
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
        vm.prank(carol);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        // 3. 任意人调用 wallet.setOrgName -> 会触发 markAfterExecuted
        vm.prank(dave);
        walletProxy.setOrgName("Executed DAO Name");

        // 4. 验证 orgName 已更新
        assertEq(walletProxy.orgName(), "Executed DAO Name");

        // 5. 验证 indexOfUnexecutedProposals 被清空
        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props.length, 0);
    }

    function test_ExecuteSetOrgName_Revert_NotFullySigned() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("New DAO Name");

        // 0 签名 -> markAfterExecuted 返回 false -> revert
        vm.prank(dave);
        vm.expectRevert("markAsExecuted error");
        walletProxy.setOrgName("New DAO Name");

        // 补 1 个签名（阈值 2）-> 仍不够
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        vm.prank(dave);
        vm.expectRevert("markAsExecuted error");
        walletProxy.setOrgName("New DAO Name");
    }

    function test_ExecuteSetOrgName_Revert_NoProposal() public {
        // 无任何提案，markAfterExecuted 返回 false -> revert
        vm.prank(dave);
        vm.expectRevert("markAsExecuted error");
        walletProxy.setOrgName("Ghost Name");
    }

    function test_ExecuteSetOrgName_CannotExecuteTwice() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("Executed DAO Name");
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
        vm.prank(carol);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        vm.prank(dave);
        walletProxy.setOrgName("Executed DAO Name");
        assertEq(walletProxy.orgName(), "Executed DAO Name");

        // 再次执行 -> execFlow 已是 Executed -> 返回 false -> revert
        vm.prank(dave);
        vm.expectRevert("markAsExecuted error");
        walletProxy.setOrgName("Executed DAO Name");
    }

    // ============================================================
    // 成员管理
    // ============================================================

    function test_AddMember_WhenNoUnexecutedProposal() public {
        proposalSign.addMember(dave);
        address[] memory members = proposalSign.allMembers();
        assertEq(members.length, 4);
        assertEq(members[3], dave);
    }

    function test_Revert_AddMember_WhenUnexecutedProposalExists() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("New DAO Name");

        vm.expectRevert("Still remains unexecuted proposals");
        proposalSign.addMember(dave);
    }

    function test_AddMember_AfterProposalExecuted() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("New DAO Name");
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
        vm.prank(carol);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        vm.prank(dave);
        walletProxy.setOrgName("New DAO Name");

        proposalSign.addMember(dave);
        address[] memory members = proposalSign.allMembers();
        assertEq(members.length, 4);
    }

    function test_RemoveMember() public {
        proposalSign.removeMember(alice);
        address[] memory members = proposalSign.allMembers();
        assertEq(members.length, 2);
        assertEq(members[0], bob);
        assertEq(members[1], carol);
    }

    // ============================================================
    // hash 稳定性
    // ============================================================

    function test_HashStable_SameSignersSameProposal() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("A");

        // 同样 (proposal, signers) -> hash 相同 -> 返回 false
        vm.prank(alice);
        assertFalse(proposalSign.proposeOrgNameChange("B"));
    }
}