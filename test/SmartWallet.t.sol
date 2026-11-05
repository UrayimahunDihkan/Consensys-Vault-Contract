// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SmartWallet} from "../src/SmartWallet.sol";

// 辅助合约：用于测试外部调用和重入攻击
contract TargetContract {
    uint256 public value;

    function setValue(uint256 _value) external payable {
        value = _value;
    }
}

contract Attacker {
    SmartWallet public wallet;
    bool public attacked;

    constructor(SmartWallet _wallet) {
        wallet = _wallet;
    }

    // 尝试重入攻击
    function attack(address target, bytes calldata data) external payable {
        wallet.execute{value: msg.value}(target, msg.value, data);
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            // 恶意重入：尝试再次调用 execute
            // 预期会因为 nonReentrant 报错回滚
            wallet.execute(address(this), 0, "");
        }
    }
}

contract SmartWalletTest is Test {
    SmartWallet public wallet;
    TargetContract public target;
    
    address public owner;
    address public entryPointMock;

    // 修改测试合约里的 setUp 函数
    function setUp() public {
        owner = makeAddr("owner");
        
        // ✅ 修改为 OpenZeppelin v5.7 硬编码的 EntryPoint v0.9 地址
        entryPointMock = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;
        
        wallet = new SmartWallet(owner);
        target = new TargetContract();

        vm.deal(address(wallet), 10 ether);
    }

    // ================== 基础功能测试 ==================

    // 测试接收 ETH
    function test_ReceiveETH() public {
        vm.deal(address(this), 1 ether);
        (bool success, ) = address(wallet).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(wallet).balance, 11 ether);
    }

    // 测试 EntryPoint 调用 execute 转账
    function test_ExecuteTransfer() public {
        address recipient = makeAddr("recipient");

        // ✅ 模拟 EntryPoint 发起的调用
        vm.prank(entryPointMock);
        wallet.execute(recipient, 1 ether, "");

        assertEq(recipient.balance, 1 ether);
        assertEq(address(wallet).balance, 9 ether);
    }

    // 测试 EntryPoint 调用 execute 触发外部合约逻辑（带 data）
    function test_ExecuteWithData() public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 42);

        vm.prank(entryPointMock);
        wallet.execute(address(target), 0, data);

        assertEq(target.value(), 42);
    }

    // ================== 安全控制测试 ==================

    // 测试：非 EntryPoint 且非自己调用时，必须 revert
    function test_RevertIf_CallerIsNotEntryPoint() public {
        address hacker = makeAddr("hacker");
        
        // 黑客直接尝试调用 execute 偷钱
        vm.prank(hacker);
        // 预期报错：AccountUnauthorized
        vm.expectRevert(abi.encodeWithSignature("AccountUnauthorized(address)", hacker));
        wallet.execute(hacker, 1 ether, "");
    }

    // 测试：防重入锁是否生效
    function test_RevertIf_ReentrancyAttack() public {
        Attacker attacker = new Attacker(wallet);
        
        // 给攻击者充值一点 ETH 发起攻击
        vm.deal(address(attacker), 1 ether);

        // 模拟 EntryPoint 调用攻击者的 attack 函数（这里为了方便测试，我们直接 prank EntryPoint）
        // 实际上，在真实场景中，攻击者是通过自己构造恶意合约并在 receive 中重入
        vm.prank(entryPointMock);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        
        // 发起攻击
        attacker.attack{value: 1 ether}(address(target), "");
    }
}