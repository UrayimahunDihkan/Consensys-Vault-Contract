// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SmartWallet} from "../src/v1/SmartWallet.sol";
import {PackedUserOperation} from "@openzeppelin/contracts/interfaces/IERC4337.sol";
import {IEntryPointExtra} from "@openzeppelin/contracts/account/utils/ERC4337Utils.sol";

contract SmartWalletSignatureTest is Test {
    SmartWallet wallet;

    uint256 ownerPrivateKey = 0xA11CE;
    address owner;

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        wallet = new SmartWallet("UYGHUR DAO", owner);
    }

    function testValidUserOpSignature() public {
        bytes32 userOpHash = keccak256("test user operation");

        (uint8 v, bytes32 r, bytes32 s) =
                            vm.sign(ownerPrivateKey, userOpHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp;
        userOp.sender = address(wallet);
        userOp.signature = signature;

        vm.prank(address(wallet.entryPoint()));

        uint256 result = wallet.validateUserOp(
            userOp,
            userOpHash,
            0
        );

        assertEq(result, 0);
    }


    function testInvalidUserOpSignature() public {
        bytes32 userOpHash = keccak256("test user operation");

        // 使用另一个私钥签名
        uint256 attackerPrivateKey = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) =
                            vm.sign(attackerPrivateKey, userOpHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp;
        userOp.sender = address(wallet);
        userOp.signature = signature;

        vm.prank(address(wallet.entryPoint()));

        uint256 result = wallet.validateUserOp(
            userOp,
            userOpHash,
            0
        );

        // ERC-4337 签名失败标志为 1
        assertEq(result, 1);
    }

    //  forge test --fork-url "$BSC_RPC_URL" --match-test testRealEntryPointUserOpHash -vvv
    function testRealEntryPointUserOpHash() public {
        PackedUserOperation memory userOp;

        userOp.sender = address(wallet);
        userOp.nonce = 0;
        userOp.initCode = "";
        userOp.callData = "";
        userOp.accountGasLimits = bytes32(0);
        userOp.preVerificationGas = 0;
        userOp.gasFees = bytes32(0);
        userOp.paymasterAndData = "";
        userOp.signature = "";

        // 调用真实 EntryPoint 的 getUserOpHash()
        bytes32 userOpHash =IEntryPointExtra(address(wallet.entryPoint())).getUserOpHash(userOp);

        // 使用 Owner 私钥签署真实 Hash
        (uint8 v, bytes32 r, bytes32 s) =
                            vm.sign(ownerPrivateKey, userOpHash);

        userOp.signature = abi.encodePacked(r, s, v);

        // 模拟 EntryPoint 调用钱包验证
        vm.prank(address(wallet.entryPoint()));

        uint256 result = wallet.validateUserOp(
            userOp,
            userOpHash,
            0
        );

        assertEq(result, 0);
    }
}