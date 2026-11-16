// script/UpgradeUUPSProxy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ConsensusWallet } from "../../src/consensus-wallet/ConsensusWallet.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";


contract UpgradeUUPSProxyScript is Script {

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY");

        console.log("========================================");
        console.log("Proxy address:", proxyAddress);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        // deploy new Implementation
        ConsensusWallet newImpl = new ConsensusWallet();
        console.log("New ConsensusWallet implementation:", address(newImpl));

        // upgrade
        // 1. 使用 payable(proxyAddress) 进行转换
        // 2. 使用 upgradeToAndCall 替代 upgradeTo
        ConsensusWallet old = ConsensusWallet(payable(proxyAddress));
        old.upgradeToAndCall(address(newImpl), "");

        console.log("Upgrade executed successfully!");

        vm.stopBroadcast();

    }

}