pragma solidity ^0.8.24;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

interface IProposalSign {
    function markAfterExecuted(uint8 _proposal) external returns (bool);
}

contract ConsensusWallet is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard {

    string public orgName;
    address public proposalSignAddress;

    receive() external payable {}

    function setOrgName(string calldata _newOrgValue) external {
        orgName = _newOrgValue;
        // Proposal.ORG_NAME_CHANG -> 0
        bool success = IProposalSign(proposalSignAddress).markAfterExecuted(0);
        if (!success) {
            revert("markAsExecuted error");
        }
    }

    // core
//    function execute(address target, uint256 value, bytes calldata data)
//        external
//        payable
//    nonReentrant
//    {
//        (bool success, ) = target.call{ value: value } ( data );
//        require(success, "Execution Failed");
//    }


    // 从V2开始这个不用
    function initialize(string memory _orgName, address _proposalSignAddress) public initializer {
        __Ownable_init(_msgSender());
        orgName = _orgName;
        proposalSignAddress = _proposalSignAddress;
    }

    // 只需要又这个就行 (主要是验证onlyOwner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}





    // setter
    function setProposalSignAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");
        proposalSignAddress = _newAddress;
    }

}