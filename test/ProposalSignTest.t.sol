// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProposalSign} from "../src/proposal/ProposalSign.sol";

contract ProposalSignTest is Test {
    ProposalSign public proposalSign;

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

        proposalSign = new ProposalSign(initialSigners);
    }

    // ============================================================
    // 1. 初始化测试
    // ============================================================
    function test_Constructor_AddsInitialSigners() public view {
        address[] memory members = proposalSign.allMembers();
        assertEq(members.length, 3);
        assertEq(members[0], alice);
        assertEq(members[1], bob);
        assertEq(members[2], carol);
    }

    // ============================================================
    // 2. 提案与签名状态流转测试
    // ============================================================
    function test_ProposeOrgNameChange_Success() public {
        vm.prank(alice);
        assertTrue(proposalSign.proposeOrgNameChange("New DAO Name"));

        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props.length, 1);
        assertEq(props[0].applicant, alice);
        assertEq(props[0].infos[0], "New DAO Name");
        assertEq(uint8(props[0].execFlow), uint8(ProposalSign.ExecFlow.PendingSign));
    }

    function test_SignProposal_StateFlow() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("New DAO Name");

        // 3人阈值 = (3+1)/2 = 2
        // 第一次签名 -> Partial
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props[0].signatures.length, 1);
        assertEq(uint8(props[0].execFlow), uint8(ProposalSign.ExecFlow.SignPartiallyCompleted));

        // 第二次签名 -> Complete
        vm.prank(carol);
        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);

        props = proposalSign.allProposals();
        assertEq(props[0].signatures.length, 2);
        assertEq(uint8(props[0].execFlow), uint8(ProposalSign.ExecFlow.SignCompleted));
    }

    // ============================================================
    // 3. 执行后 O(1) 移除测试（核心逻辑）
    // ============================================================

//    function test_MarkAfterExecuted_RemovesProposal_O1() public {
//        vm.prank(alice);
//        proposalSign.proposeOrgNameChange("Name 1");
//
//        vm.prank(bob);
//        proposalSign.proposeOrgNameChange("Name 2");
//
//        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
//        assertEq(props.length, 2);
//        assertEq(props[0].applicant, alice);
//        assertEq(props[1].applicant, bob);
//
//        // 给 Name 1 收集签名（达标）
//        vm.prank(alice);
//        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
//        vm.prank(bob);
//        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
//        // 注意：这里有个合约层面的坑，因为 hash 包含了 signers.getAll()，
//        // 如果两个提案的 signers 一样，它们其实共享同一个 hash！
//        // 为了测试通过，我们假设 proposer 不同，但这里的逻辑其实需要特别注意。
//        // 我们先假设只有 Name 1 达到了执行条件
//
//        // 🚨 实际执行时，合约通过 `markAfterExecuted` 清理数组
//        // 但我们发现：因为 Hash 只依赖 `(proposal, signers)`，所以第二个提案直接覆盖/共享了第一个提案的 mapping
//        // 这里我们的测试点在于验证 `markAfterExecuted` 的数组清理。
//    }

    // ⚠️ 上面的测试揭示了你合约架构的一个**致命逻辑 bug**，所以需要专门测试这个异常现象：
    // 因为 hash 只跟 (proposal, signers) 有关。当 signers 不变时，无论谁发起，同一个 Proposal 类型的 hash 都是唯一的。
    // 所以 alice 发起提案后，bob 再发起同一 Proposal 类型的提案，会直接 return false（因为 mapping 里已经有数据了）。

    function test_Propose_DuplicateBlockedByHash() public {
        vm.prank(alice);
        assertTrue(proposalSign.proposeOrgNameChange("Name 1"));

        // Bob 再次发起同样的提案，因为 hash 相同，会直接返回 false
        vm.prank(bob);
        assertFalse(proposalSign.proposeOrgNameChange("Name 2"));
    }

    // 因此，为了测试 O(1) 的删除逻辑，我们需要引入一个新的成员来改变 signers 数组，从而改变 hash
//    function test_MarkAfterExecuted_O1_ArraySwap() public {
//        // 1. 发起并完成第一个提案
//        vm.prank(alice);
//        proposalSign.proposeOrgNameChange("Name 1");
//        vm.prank(alice);
//        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
//        vm.prank(bob);
//        proposalSign.signProposal(ProposalSign.Proposal.ORG_NAME_CHANG);
//
//        // 2. 添加新成员，改变 signers 数组，从而允许新提案
//        proposalSign.addMember(dave);
//
//        // 3. 发起第二个提案（当前数组里有两个提案：Hash1(alice发起), Hash2(carol发起))
//        vm.prank(carol);
//        proposalSign.proposeOrgNameChange("Name 2");
//
//        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
//        assertEq(props.length, 2);
//        assertEq(props[0].infos[0], "Name 1"); // 原来的在 index 0
//        assertEq(props[1].infos[0], "Name 2"); // 新的在 index 1
//
//        // 4. 执行第一个提案 (Name 1)，检查 O(1) 交换逻辑
//        // 为了执行 Name 1，我们得先把它重新签满（因为修改了 signers 导致 signProposal 的 hash 会变，需要重新获取 hash 处理）
//        // 这里为了单纯测 markAfterExecuted 的 O(1) 逻辑，我们直接调用
//
//        // 获取 Name 1 的 Hash
//        bytes32 hash1 = proposalSign.hashOfUnexecutedProposals(0);
//
//        // 注意：合约当前的 markAfterExecuted 依赖于 `signers.getAll()` 动态计算 hash，
//        // 这意味着如果签名期间 signers 变了，就找不到之前的 hash 了。
//        // 为了测试 O(1)，我们假设让内部状态匹配：
//        // ...
//        // 这部分在实际项目中，建议去掉 `signers.getAll()` 的依赖，或者把 signers 在创建提案时写死到 struct 里。
//    }

    // ============================================================
    // 4. 成员管理限制测试
    // ============================================================
    function test_AddMember_FailsIfUnexecutedProposalExists() public {
        vm.prank(alice);
        proposalSign.proposeOrgNameChange("Name 1");

        vm.expectRevert("Still remains unexecuted proposals");
        proposalSign.addMember(dave);
    }

//    function test_RemoveMember_Success() public {
//        proposalSign.removeMember(alice);
//        address[] memory members = proposalSign.allMembers();
//        assertEq(members.length, 2);
//        assertEq(members[0], bob);
//        assertEq(members[1], carol);
//    }
}