// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AddressSet} from "../libraries/AddressSet.sol";


interface IConsensusWallet {
    function execute(address target, uint256 value, bytes calldata data) external payable;
}

contract ProposalSign is ReentrancyGuard {

    enum ExecFlow {
        PendingSign,
        SignPartiallyCompleted,
        SignCompleted,
        Executed
    }

    enum Proposal {
        ORG_NAME_CHANG,
        TRANSFER,
        MEMBERSHIP
    }

    enum MembershipProposal {
        ADD_MEMBER,
        DELETE_MEMBER,
        NOTHING
    }

    struct SignatureInfo {
        address applicant;
        address[] signatures;
        Proposal proposal;
        // name change
        string[] infos;
        // transfer
        address transferTo;
        address transferCurrency;
        uint256 transferAmount;
        // membership
        address membershipAddr;
        MembershipProposal membershipProposal;

        ExecFlow execFlow;
    }

    using AddressSet for AddressSet.Set; // the AddressSet.Set type allows you to

    /*-------------------------storage---------------------------*/

    address public consensusWalletAddress;
    AddressSet.Set private signers;

    mapping(bytes32 => SignatureInfo) public signatureMap;
    bytes32[] public hashOfUnexecutedProposals;
    mapping(bytes32 => uint256) private proposalIndex;




    /*-------------------------storage---------------------------*/

    constructor(address[] memory _initialSigners) {
        for(uint256 i; i < _initialSigners.length; i++) {
            signers.add(_initialSigners[i]);
        }
        signers.setThreshold(calculateThreshold(_initialSigners.length));
    }


    // proposal for changing org name
    // signatureMap -> params: [ _newOrgName ]
    function proposeOrgNameChange(string calldata _newOrgName) public returns(bool) {

        bytes32 hash = getProposalHash(Proposal.ORG_NAME_CHANG, signers.getAll());
        if (signatureMap[hash].applicant != address(0) && signatureMap[hash].execFlow != ExecFlow.Executed) {
            return false;
        }

        string[] memory _infos = new string[](1);
        _infos[0] = _newOrgName;
        signatureMap[hash] = SignatureInfo({
            applicant: msg.sender,
            signatures: new address[](0),
            proposal: Proposal.ORG_NAME_CHANG,
            infos: _infos,
            execFlow: ExecFlow.PendingSign,
            transferTo: address(0),
            transferCurrency: address(0),
            transferAmount: 0,
            membershipAddr: address(0),
            membershipProposal: MembershipProposal.NOTHING
        });

        hashOfUnexecutedProposals.push(hash);
        proposalIndex[hash] = hashOfUnexecutedProposals.length;

        return true;
    }

    function proposeMembership(address _member, MembershipProposal _membershipProposal) public returns(bool) {

        require(_member!=address(0), "_member can not be empty");
        if (_membershipProposal == MembershipProposal.DELETE_MEMBER) {
            require(contains(_member), "the member you're deleting is not in signers list");
        }

        bytes32 hash = getProposalHash(Proposal.MEMBERSHIP, signers.getAll());
        if (signatureMap[hash].applicant != address(0) && signatureMap[hash].execFlow != ExecFlow.Executed) {
            return false;
        }

        signatureMap[hash] = SignatureInfo({
            applicant: msg.sender,
            signatures: new address[](0),
            proposal: Proposal.MEMBERSHIP,
            membershipAddr: _member,
            membershipProposal: _membershipProposal,
            infos: new string[](0),
            transferTo: address(0),
            transferCurrency: address(0),
            transferAmount: 0,
            execFlow: ExecFlow.PendingSign
        });

        hashOfUnexecutedProposals.push(hash);
        proposalIndex[hash] = hashOfUnexecutedProposals.length;

        return true;
    }

    function proposeTransfer(address _to, address _currency, uint256 _amount) public returns(bool)  {

        require(_to != address(0), "address can not be empty");
        require(_amount > 0, "amount should more than 0");

        bytes32 hash = getProposalHash(Proposal.TRANSFER, signers.getAll());
        if (signatureMap[hash].applicant != address(0) && signatureMap[hash].execFlow != ExecFlow.Executed) {
            return false;
        }

        signatureMap[hash] = SignatureInfo({
            applicant: msg.sender,
            signatures: new address[](0),
            proposal: Proposal.TRANSFER,
            infos: new string[](0),
            transferTo: _to,
            transferCurrency: _currency,
            transferAmount: _amount,
            membershipAddr: address(0),
            membershipProposal: MembershipProposal.NOTHING,
            execFlow: ExecFlow.PendingSign
        });

        hashOfUnexecutedProposals.push(hash);
        proposalIndex[hash] = hashOfUnexecutedProposals.length;

        return true;
    }


    function allProposals() public view returns(SignatureInfo[] memory) {

        uint256 proposalLen = hashOfUnexecutedProposals.length;
        if (proposalLen <= 0) {
            return new SignatureInfo[](0);
        }

        SignatureInfo[] memory sigInfo = new SignatureInfo[](proposalLen);
        for (uint256 i=0; i < proposalLen; i++) {
            sigInfo[i]=signatureMap[hashOfUnexecutedProposals[i]];
        }

        return sigInfo;
    }

    function signProposal(Proposal _proposal) public returns(bool) {

        require(signers.contains(msg.sender), "Not a signer");

        bytes32 hash = getProposalHash(_proposal, signers.getAll());
        SignatureInfo storage sigInfo = signatureMap[hash];
        require(sigInfo.applicant != address(0), "This proposal doesn't exist");
        sigInfo.signatures.push(msg.sender);

        sigInfo.execFlow = sigInfo.signatures.length >= signers.getThreshold() ?
                                    ExecFlow.SignCompleted :
                                    ExecFlow.SignPartiallyCompleted;

        return true;
    }


    /*-------------------------------- exec ---------------------------------*/

    function execTransfer() nonReentrant public returns(bool) {

        bytes32 hash = getProposalHash(Proposal.TRANSFER, signers.getAll());
        SignatureInfo storage sigInfo = signatureMap[hash];
        require(sigInfo.execFlow == ExecFlow.SignCompleted, "Sign not completed");

        sigInfo.execFlow = ExecFlow.Executed;

        if (sigInfo.transferCurrency == address(0)) {
            // base coin transfer
            IConsensusWallet(consensusWalletAddress).execute{value: 0}(
                sigInfo.transferTo,
                sigInfo.transferAmount,
                ""
            );
        } else {
            // ERC20 transfer
            bytes memory data = abi.encodeWithSignature(
                "transfer(address,uint256)",
                sigInfo.transferTo,
                sigInfo.transferAmount
            );
            IConsensusWallet(consensusWalletAddress).execute{value: 0} (
                sigInfo.transferCurrency,
                0,
                data
            );
        }

        uint256 indexPlusOne = proposalIndex[hash];
        if (indexPlusOne > 0) {
            uint256 indexToRemove = indexPlusOne - 1;
            uint256 lastIndex = hashOfUnexecutedProposals.length - 1;

            if (indexToRemove != lastIndex) {
                bytes32 lastHash = hashOfUnexecutedProposals[lastIndex];
                hashOfUnexecutedProposals[indexToRemove] = lastHash;
                proposalIndex[lastHash] = indexToRemove + 1;
            }

            hashOfUnexecutedProposals.pop();
            delete proposalIndex[hash];
        }

        return true;
    }

    function execMembership() public returns(bool) {
        bytes32 hash = getProposalHash(Proposal.MEMBERSHIP, signers.getAll());
        SignatureInfo storage sigInfo = signatureMap[hash];
        require(sigInfo.execFlow == ExecFlow.SignCompleted, "Sign not completed");

        if (sigInfo.membershipProposal == MembershipProposal.ADD_MEMBER) {
            require(!signers.contains(sigInfo.membershipAddr), "member already exist in signers list");
            addMember(sigInfo.membershipAddr);
        } else if (sigInfo.membershipProposal == MembershipProposal.DELETE_MEMBER) {
            require(signers.contains(sigInfo.membershipAddr), "member not exist in signers list");
            removeMember(sigInfo.membershipAddr);
        }

        sigInfo.execFlow = ExecFlow.Executed;

        uint256 indexPlusOne = proposalIndex[hash];
        if (indexPlusOne > 0) {
            uint256 indexToRemove = indexPlusOne - 1;
            uint256 lastIndex = hashOfUnexecutedProposals.length - 1;

            if (indexToRemove != lastIndex) {
                bytes32 lastHash = hashOfUnexecutedProposals[lastIndex];
                hashOfUnexecutedProposals[indexToRemove] = lastHash;
                proposalIndex[lastHash] = indexToRemove + 1;
            }

            hashOfUnexecutedProposals.pop();
            delete proposalIndex[hash];
        }

        return true;
    }


    function markAfterExecuted(Proposal _proposal) external returns (bool)  {
        bytes32 hash = getProposalHash(_proposal, signers.getAll());
        SignatureInfo storage sigInfo = signatureMap[hash];

        if (sigInfo.execFlow != ExecFlow.SignCompleted) {
            return false;
        }
        sigInfo.execFlow = ExecFlow.Executed;

        uint256 indexPlusOne = proposalIndex[hash];
        if (indexPlusOne > 0) {
            uint256 indexToRemove = indexPlusOne - 1;
            uint256 lastIndex = hashOfUnexecutedProposals.length - 1;

            if (indexToRemove != lastIndex) {
                bytes32 lastHash = hashOfUnexecutedProposals[lastIndex];
                hashOfUnexecutedProposals[indexToRemove] = lastHash;
                proposalIndex[lastHash] = indexToRemove + 1;
            }

            hashOfUnexecutedProposals.pop();
            delete proposalIndex[hash];
        }

        return true;
    }

    /*-------------------------------- exec ---------------------------------*/



    // membership
    function addMember(address _addr) public {
        signers.add(_addr);  // Elegant call: directly invoke the method on the variable!
        signers.setThreshold(calculateThreshold(signers.length()));
    }
    function removeMember(address _addr) public {
        signers.remove(_addr);
        signers.setThreshold(calculateThreshold(signers.length()));
    }
    function allMembers() public view returns(address[] memory) {
        return signers.getAll();
    }
    function contains(address _signer) public view returns(bool) {
        return signers.contains(_signer);
    }




    // private methods
    function getProposalHash(Proposal _proposal, address[] memory _signers) internal pure returns(bytes32) {
        return keccak256(abi.encode(_proposal, _signers));
    }

    function getSignatureInfo(bytes32 hash) external view returns (SignatureInfo memory) {
        return signatureMap[hash];
    }

    function calculateThreshold(uint256 howManySigners) internal pure returns (uint256) {
        return (howManySigners + 1) / 2; // Round up
    }


    // set
    function setConsensusWalletAddress(address _consensusWalletAddress) public returns(bool) {
        consensusWalletAddress = _consensusWalletAddress;
        return true;
    }

}