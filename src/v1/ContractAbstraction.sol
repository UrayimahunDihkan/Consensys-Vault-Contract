pragma solidity ^0.8.24;

import {Account} from "@openzeppelin/contracts/account/Account.sol";
import {SignerECDSA} from "@openzeppelin/contracts/utils/cryptography/signers/SignerECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract ContractAbstraction is Account, SignerECDSA, ReentrancyGuard {

    string public orgName;

    constructor(string memory _orgName,
                address _initialOwner)
        SignerECDSA(_initialOwner)
    {
        orgName = _orgName;
    }

    function setOrgName(string memory _newOrgName) external onlyEntryPointOrSelf {
        orgName = _newOrgName;
    }

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