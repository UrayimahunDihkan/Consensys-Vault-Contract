// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ProposalSign } from "../../src/proposal/ProposalSign.sol";

contract MultisignDeploy is Script {
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ProposalSign proposalSign = new ProposalSign();
        console.log("Proposal sign contract deployed at:", address(proposalSign));

        vm.stopBroadcast();

        console.log("========================================");
        console.log(" Deployment completed successfully!");
        console.log("========================================");
    }
}