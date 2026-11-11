// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AddressSet {

    struct Set {
        address[] values;
        mapping(address => uint256) indexes;
    }

    function add(Set storage self, address value) internal returns (bool) {

        if (self.indexes[value] != 0) {
            return false;
        }

        self.values.push(value);
        self.indexes[value] = self.values.length; // maintainedIndex =  real_index+1

        return true;
    }

    function remove(Set storage self, address value) internal returns (bool) {

        uint256 index = self.indexes[value]; // maintainedIndex
        if (index==0) {
            return false;
        }

        uint256 toDeleteIndex = index - 1;
        uint256 lastIndex = self.values.length - 1;
        address lastAddress = self.values[lastIndex];

        self.values[toDeleteIndex] = lastAddress;
        self.indexes[lastAddress] = toDeleteIndex;

        self.values.pop();
        delete self.indexes[value];

        return true;
    }

    function contains(Set storage self, address value) internal view returns(bool) {
        return self.indexes[value] != 0;
    }

    function getAll(Set storage self) internal view returns(address[] memory) {
        return self.values;
    }

    function length(Set storage self) internal view returns (uint256) {
        return self.values.length;
    }

}