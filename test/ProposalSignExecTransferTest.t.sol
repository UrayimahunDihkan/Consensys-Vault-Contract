// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProposalSign} from "../src/proposal/ProposalSign.sol";

// 模拟 ConsensusWallet 合约
contract MockConsensusWallet {
    event Executed(address target, uint256 value, bytes data);

    function execute(address target, uint256 value, bytes calldata data) external payable {
        emit Executed(target, value, data);
    }
}

contract ProposalSignExecTransferTest is Test {
    ProposalSign public proposalSign;
    MockConsensusWallet public mockWallet;

    address internal alice = address(0xA11CE);
    address internal bob   = address(0xB0B);
    address internal carol = address(0xCA401);
    address internal recipient = address(0x1111);
    address internal mockToken = address(0x2222);

    address[] internal initialSigners;

    function setUp() public {
        // 1. 初始化多签成员 (3人 -> 阈值 2)
        initialSigners = new address[](3);
        initialSigners[0] = alice;
        initialSigners[1] = bob;
        initialSigners[2] = carol;

        proposalSign = new ProposalSign(initialSigners);

        // 2. 部署 Mock Wallet 并设置到 ProposalSign
        mockWallet = new MockConsensusWallet();
        proposalSign.setConsensusWalletAddress(address(mockWallet));
    }

    // 辅助函数：创建一个已完全签名的 Transfer 提案
    function _createAndSignTransfer(address currency, uint256 amount) internal {
        // 发起提案
        vm.prank(alice);
        proposalSign.proposeTransfer(recipient, currency, amount);

        // 签名两次达到阈值 (2)
        vm.prank(alice);
        proposalSign.signProposal(ProposalSign.Proposal.TRANSFER);
        vm.prank(bob);
        proposalSign.signProposal(ProposalSign.Proposal.TRANSFER);
    }

    // ============================================================
    // 测试 1：原生代币转账 (RBTC)
    // ============================================================
    function test_ExecTransfer_NativeCoin() public {
        uint256 amount = 1 ether;
        _createAndSignTransfer(address(0), amount);

        // 期望调用 mockWallet.execute(recipient, 1 ether, "")
        vm.expectEmit(true, true, true, true, address(mockWallet));
        emit MockConsensusWallet.Executed(recipient, amount, "");

        // 执行
        proposalSign.execTransfer();

        // 验证提案已被清理（数组变空）
        ProposalSign.SignatureInfo[] memory props = proposalSign.allProposals();
        assertEq(props.length, 0);
    }

    // ============================================================
    // 测试 2：ERC20 代币转账
    // ============================================================
    function test_ExecTransfer_ERC20() public {
        uint256 amount = 500 * 10**6; // 假设是 USDT，6 位精度
        _createAndSignTransfer(mockToken, amount);

        // 构造期望的 calldata
        bytes memory expectedData = abi.encodeWithSignature("transfer(address,uint256)", recipient, amount);

        // 期望调用 mockWallet.execute(mockToken, 0, expectedData)
        vm.expectEmit(true, true, true, true, address(mockWallet));
        emit MockConsensusWallet.Executed(mockToken, 0, expectedData);

        // 执行
        proposalSign.execTransfer();

        // 验证提案已被清理
        assertEq(proposalSign.allProposals().length, 0);
    }

    // ============================================================
    // 测试 3：签名未完成时不能执行
    // ============================================================
    function test_Revert_ExecTransfer_NotFullySigned() public {
        // 发起提案，但只签 1 个人
        vm.prank(alice);
        proposalSign.proposeTransfer(recipient, address(0), 1 ether);

        vm.prank(alice);
        proposalSign.signProposal(ProposalSign.Proposal.TRANSFER);

        // 尝试执行，应该报错
        vm.expectRevert("Sign not completed");
        proposalSign.execTransfer();
    }

    // ============================================================
    // 测试 4：重复执行会被拦截
    // ============================================================
    function test_Revert_ExecTransfer_AlreadyExecuted() public {
        _createAndSignTransfer(address(0), 1 ether);

        // 第一次执行成功
        proposalSign.execTransfer();

        // 第二次执行会失败，因为 hash 对应的 execFlow 已经变成了 Executed
        vm.expectRevert("Sign not completed");
        proposalSign.execTransfer();
    }
}
