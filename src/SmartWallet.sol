pragma solidity ^0.8.24;

import {Account} from "@openzeppelin/contracts/account/Account.sol";
import {SignerECDSA} from "@openzeppelin/contracts/utils/cryptography/signers/SignerECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";




contract SmartWallet is Account, SignerECDSA, ReentrancyGuard {

    constructor(address _initialOwner) SignerECDSA(_initialOwner) {}

    receive() external payable override {}

    function execute(address target, uint256 value, bytes calldata data)
        external 
        payable
        nonReentrant
        onlyEntryPointOrSelf
    {
        (bool success, ) = target.call{ value: value } ( data );
        require(success, "Execution Failed");
    }



}