// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SmartWallet} from "../src/SmartWallet.sol";

contract SmartWalletTest is Test {
    SmartWallet public wallet;

    address public owner;
    address public entryPointMock;

    function setUp() public {
        owner = makeAddr("owner");

        // OpenZeppelin v5.7 默认的 EntryPoint v0.9 地址
        entryPointMock = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

        // 部署钱包，传入 DAO 名字和 Owner
        wallet = new SmartWallet("My Awesome DAO", owner);

        // 往钱包里充 10 个 ETH 用于测试
        vm.deal(address(wallet), 10 ether);
    }

    // ================== 基础属性测试 ==================

    function test_InitialOrgName() public view {
        assertEq(wallet.orgName(), "My Awesome DAO", "Org name should be initialized correctly");
    }

    function test_ReceiveETH() public {
        // 模拟别人给钱包打钱
        vm.deal(address(this), 1 ether);
        (bool success, ) = address(wallet).call{value: 1 ether}("");
        assertTrue(success, "Wallet should accept ETH");
        assertEq(address(wallet).balance, 11 ether);
    }

    // ================== 核心 execute 测试 ==================

    function test_ExecuteTransferETH() public {
        address recipient = makeAddr("recipient");

        // 模拟 EntryPoint 发起的调用
        vm.prank(entryPointMock);
        wallet.execute(recipient, 1 ether, "");

        assertEq(recipient.balance, 1 ether, "Recipient should receive 1 ETH");
        assertEq(address(wallet).balance, 9 ether, "Wallet balance should decrease");
    }

    // ================== 安全校验测试 ==================

    function test_RevertIf_NotEntryPoint() public {
        address hacker = makeAddr("hacker");

        // 模拟黑客直接调用 execute 偷钱
        vm.prank(hacker);

        // 预期报错：AccountUnauthorized
        vm.expectRevert(abi.encodeWithSignature("AccountUnauthorized(address)", hacker));
        wallet.execute(hacker, 1 ether, "");
    }
}