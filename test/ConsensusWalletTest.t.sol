// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ConsensusWallet} from "../src/consensus-wallet/ConsensusWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Mock ProposalSign 合约，用于测试跨合约调用返回值
contract MockProposalSign {
    bool public shouldSucceed = true;
    uint8 public lastProposalCalled;

    function setShouldSucceed(bool _val) external {
        shouldSucceed = _val;
    }

    function markAfterExecuted(uint8 _proposal) external returns (bool) {
        lastProposalCalled = _proposal;
        return shouldSucceed;
    }
}

contract ConsensusWalletTest is Test {
    ConsensusWallet public walletImpl;
    ConsensusWallet public walletProxy;
    MockProposalSign public mockProposalSign;

    address internal owner = address(this);
    address internal alice = address(0xA11CE);

    function setUp() public {
        // 1. 部署 Mock ProposalSign
        mockProposalSign = new MockProposalSign();

        // 2. 部署 ConsensusWallet Implementation
        walletImpl = new ConsensusWallet();

        // 3. 准备初始化参数
        bytes memory initData = abi.encodeWithSelector(
            ConsensusWallet.initialize.selector,
            "Original DAO Name",
            address(mockProposalSign)
        );

        // 4. 部署 Proxy 并初始化
        ERC1967Proxy proxy = new ERC1967Proxy(address(walletImpl), initData);
        walletProxy = ConsensusWallet(payable(address(proxy)));
    }

    // ============================================================
    // 1. 初始化测试
    // ============================================================

    function test_Initialize() public view {
        assertEq(walletProxy.orgName(), "Original DAO Name");
        assertEq(walletProxy.proposalSignAddress(), address(mockProposalSign));
        assertEq(walletProxy.owner(), owner);
    }

    function test_Revert_Initialize_Twice() public {
        vm.expectRevert();
        walletProxy.initialize("Another Name", address(0));
    }

    // ============================================================
    // 2. setOrgName 测试
    // ============================================================

    function test_SetOrgName_Success() public {
        // 设置 Mock 返回 true
        mockProposalSign.setShouldSucceed(true);

        vm.prank(alice);
        walletProxy.setOrgName("New DAO Name");

        // 验证 orgName 被更新
        assertEq(walletProxy.orgName(), "New DAO Name");

        // 验证跨合约调用传递了正确的参数 (0 代表 ORG_NAME_CHANG)
        assertEq(mockProposalSign.lastProposalCalled(), 0);
    }

    function test_Revert_SetOrgName_MarkFailed() public {
        // 设置 Mock 返回 false
        mockProposalSign.setShouldSucceed(false);

        vm.prank(alice);
        vm.expectRevert("markAsExecuted error");
        walletProxy.setOrgName("Failed Name");
    }

    // ============================================================
    // 3. 权限控制测试 (setProposalSignAddress)
    // ============================================================

    function test_SetProposalSignAddress() public {
        address newSignAddress = address(0x1234);

        // 当前测试合约是 owner，可以修改
        walletProxy.setProposalSignAddress(newSignAddress);
        assertEq(walletProxy.proposalSignAddress(), newSignAddress);
    }

    function test_Revert_SetProposalSignAddress_NotOwner() public {
        address newSignAddress = address(0x1234);

        // 非 owner 尝试修改
        vm.prank(alice);
        vm.expectRevert(); // Ownable: caller is not the owner
        walletProxy.setProposalSignAddress(newSignAddress);
    }

    function test_Revert_SetProposalSignAddress_ZeroAddress() public {
        // Owner 尝试设置为零地址
        vm.expectRevert("Invalid address");
        walletProxy.setProposalSignAddress(address(0));
    }
}