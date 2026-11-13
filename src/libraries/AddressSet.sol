// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AddressSet {

    struct Set {
        address[] values;
        mapping(address => uint256) indexes;
        uint256 threshold;
    }

    function add(Set storage self, address value) internal returns (bool) {

        if (self.indexes[value] != 0) {
            // duplicate
            return false;
        }

        self.values.push(value);
        self.indexes[value] = self.values.length; // maintainedIndex =  real_index+1

        return true;
    }

    // to do , have issue in test.
    function remove(Set storage self, address value) internal returns (bool) {

        uint256 index = self.indexes[value]; // maintainedIndex
        if (index==0) {
            return false;
        }

        uint256 toDeleteIndex = index - 1;
        uint256 lastIndex = self.values.length - 1;
        address lastAddress = self.values[lastIndex];

        self.values[toDeleteIndex] = lastAddress;
        self.indexes[lastAddress] = toDeleteIndex + 1;

        self.values.pop();
        delete self.indexes[value];

        return true;
    }

    function setThreshold(Set storage self, uint256 _threshold) internal returns (bool) {
        self.threshold = _threshold;
        return true;
    }

    function getThreshold(Set storage self) internal view returns (uint256) {
        return self.threshold;
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