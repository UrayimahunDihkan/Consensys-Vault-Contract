// script/DeployUUPSProxy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSProxy } from "../../src/consensus-wallet/UUPSProxy.sol";
import { ConsensusWallet } from "../../src/consensus-wallet/ConsensusWallet.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";


contract DeployUUPSProxyScript is Script {

    function run() external {
        // 从环境变量获取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 部署实现合约 (ConsensusWallet)
        ConsensusWallet implementation = new ConsensusWallet();
        console.log("ConsensusWallet address:", address(implementation));


        // 部署自定义 UUPS 代理
        bytes memory initData = abi.encodeWithSelector(
            ConsensusWallet.initialize.selector,
            "UYGHUR DAO"
        );
        UUPSProxy proxy = new UUPSProxy(address(implementation), initData);
        console.log("UUPSProxy address:", address(proxy));

        vm.stopBroadcast();


    }

}