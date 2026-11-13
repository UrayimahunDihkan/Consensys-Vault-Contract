// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {AddressSet} from "../libraries/AddressSet.sol";

contract ProposalSign {

    enum ExecFlow {
        PendingSign,
        SignPartiallyCompleted,
        SignCompleted,
        Executed
    }

    struct SignatureInfo {
        address applicant;
        address[] signatures;
        Proposal proposal;
        string[] infos;
        ExecFlow execFlow;
    }

    enum Proposal {
        ORG_NAME_CHANG,
        TRANSFER,
        MEMBERSHIP
    }

    using AddressSet for AddressSet.Set; // the AddressSet.Set type allows you to

    /*-------------------------storage---------------------------*/

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
        if (signatureMap[hash].applicant != address(0)) {
            return false;
        }

        string[] memory _infos = new string[](1);
        _infos[0] = _newOrgName;
        signatureMap[hash] = SignatureInfo({
            applicant: msg.sender,
            signatures: new address[](0),
            proposal: Proposal.ORG_NAME_CHANG,
            infos: _infos,
            execFlow: ExecFlow.PendingSign
        });

        hashOfUnexecutedProposals.push(hash);
        proposalIndex[hash] = hashOfUnexecutedProposals.length + 1;

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

        bytes32 hash = getProposalHash(_proposal, signers.getAll());
        SignatureInfo storage sigInfo = signatureMap[hash];
        require(sigInfo.applicant != address(0), "This proposal doesn't exist");
        sigInfo.signatures.push(msg.sender);

        sigInfo.execFlow = sigInfo.signatures.length >= signers.getThreshold() ?
                                    ExecFlow.SignCompleted :
                                    ExecFlow.SignPartiallyCompleted;

        return true;
    }




    // membership
    function addMember(address _addr) public {
        require(hashOfUnexecutedProposals.length == 0, "Still remains unexecuted proposals");
        signers.add(_addr);  // Elegant call: directly invoke the method on the variable!
    }
    function removeMember(address _addr) public {
        signers.remove(_addr);
    }
    function allMembers() public view returns(address[] memory) {
        return signers.getAll();
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



    // externals
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

}