// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {AddressSet} from "../libraries/AddressSet.sol";

contract ProposalSign {

    struct SignatureInfo {
        address applicant;
        address[] signatures;
        Proposal proposal;
        string[] infos;
    }

    enum Proposal {
        ORG_NAME_CHANG,
        TRANSFER,
        MEMBERSHIP
    }


    using AddressSet for AddressSet.Set; // the AddressSet.Set type allows you to

    AddressSet.Set private signers;

    mapping(bytes32 => SignatureInfo) public signatureMap;
    bytes32[] public indexOfUnsignedProposals;


    // proposal for changing org name
    // signatureMap -> params: [ _newOrgName ]
    function proposeOrgNameChange(string calldata _newOrgName) public returns(bool) {

        bytes32 hash = getProposalHash(Proposal.ORG_NAME_CHANG, msg.sender);
        if (signatureMap[hash].applicant != address(0)) {
            return false;
        }

        string[] memory _infos = new string[](1);
        _infos[0] = _newOrgName;
        signatureMap[hash] = SignatureInfo({
            applicant: msg.sender,
            signatures: new address[](0),
            proposal: Proposal.ORG_NAME_CHANG,
            infos: _infos
        });

        indexOfUnsignedProposals.push(hash);

        return true;
    }

    function allProposals() public view returns(SignatureInfo[] memory) {

        uint256 proposalLen = indexOfUnsignedProposals.length;
        if (proposalLen <= 0) {
            return new SignatureInfo[](0);
        }

        SignatureInfo[] memory sigInfo = new SignatureInfo[](proposalLen);
        for (uint256 i=0; i < proposalLen; i++) {
            sigInfo[i]=signatureMap[indexOfUnsignedProposals[i]];
        }

        return sigInfo;
    }




    // membership
    function addMember(address _addr) public {
        signers.add(_addr);  // Elegant call: directly invoke the method on the variable!
    }
    function removeMember(address _addr) public {
        signers.remove(_addr);
    }
    function allMembers() public view returns(address[] memory) {
        return signers.getAll();
    }




    // private methods
    function getProposalHash(Proposal _proposal, address _proposer) internal pure returns(bytes32) {
        return keccak256(abi.encode(_proposal, _proposer));
    }

    function getSignatureInfo(bytes32 hash) external view returns (SignatureInfo memory) {
        return signatureMap[hash];
    }

}