// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {AddressSet} from "../libraries/AddressSet.sol";

contract Multisign {

    // the AddressSet.Set type allows you to
    using AddressSet for AddressSet.Set;

    AddressSet.Set private signers;




    // Elegant call: directly invoke the method on the variable!
    function addSigner(address _addr) public {
        signers.add(_addr);
    }
    function removeSigners(address _addr) public {
        signers.remove(_addr);
    }
    function allSigners() public view returns(address[] memory) {
        return signers.getAll();
    }

}