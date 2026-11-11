// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Multisign } from "../../src/multisign/Multisign.sol";

contract MultisignDeploy is Script {
    function run() external {
        // 1. 从环境变量读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");


        // 2. 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 3. 部署合约
        Multisign multisign = new Multisign();

        // 打印合约地址
        console.log("Multisign deployed at:", address(multisign));

        vm.stopBroadcast();

        console.log("========================================");
        console.log(" Deployment completed successfully!");
        console.log("========================================");
    }
}