pragma solidity ^0.8.24;


import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import {ContractAbstraction} from "../../src/v1/ContractAbstraction.sol";

contract SmartWalletScript is Script {


    address public constant SMART_WALLET_OWNER = address(0x79f35797df4B1692d9134D78cBe8F78eE41001Ab);
    string public constant ORG_NAME = "UYGHUR DAO";
    
    function run() external {
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ContractAbstraction wallet = new ContractAbstraction(ORG_NAME, SMART_WALLET_OWNER);
        console.log("SmartWallet deployed at:", address(wallet));
        vm.stopBroadcast();
    }
}