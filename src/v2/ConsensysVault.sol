pragma solidity ^0.8.24;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract ConsensusWallet is Ownable, ReentrancyGuard {

    string public orgName;


    constructor(string memory _orgName,
        address _initialOwner)
    Ownable(_initialOwner)
    {
        orgName = _orgName;
    }

    receive() external payable {}


    function setOrgName(string calldata _newOrgValue) external onlyOwner {
        orgName = _newOrgValue;
    }

    // core
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
    nonReentrant
    {
        (bool success, ) = target.call{ value: value } ( data );
        require(success, "Execution Failed");
    }

}