// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

library ArrayUtils {

    function contains(string[] storage arr, string memory val) internal view returns (bool) {
        bytes32 hashVal = keccak256(bytes(val));
        for (uint i = 0; i < arr.length; i++) {
            if (keccak256(bytes(arr[i])) == hashVal) return true;
        }
        return false;
    }

    function sum(uint[] storage arr) internal view returns (uint) {
        uint total;
        for (uint i = 0; i < arr.length; i++) total += arr[i];
        return total;
    }

    function increment(uint[] storage arr, uint8 porcentaje) internal {
        for (uint i = 0; i < arr.length; i++) {
            arr[i] = arr[i] * (100 + porcentaje) / 100;
        }
    }
}