// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ProposalSign } from "../../src/proposal/ProposalSign.sol";

contract MultisignDeploy is Script {
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address[] memory _initialSigners = new address[](2);
        _initialSigners[0]=address(0x79f35797df4B1692d9134D78cBe8F78eE41001Ab);
        _initialSigners[1]=address(0x67Fe1a6E07a5253cADE96bbC6b294a6204676649);
        ProposalSign proposalSign = new ProposalSign(_initialSigners);
        console.log("Proposal sign contract deployed at:", address(proposalSign));

        vm.stopBroadcast();

        console.log("========================================");
        console.log(" Deployment completed successfully!");
        console.log("========================================");
    }
}