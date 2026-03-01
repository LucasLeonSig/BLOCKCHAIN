// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
library  ArrayUtils{
    function contains(string[] calldata arr, string calldata val) internal pure returns(bool){
        bytes32 hashVal = keccak256(bytes(val));
        for(uint i = 0; i < arr.length; i++){
            if(keccak256(bytes(arr[i])) == hashVal) return true;
        }
        return false;
    }

    function sum(uint[] calldata arr) internal pure returns(uint){
        uint sol;
        for(uint i = 0; i < arr.length; i++) sol+= arr[i];
        return sol;
    }

    function increment(uint[] memory arr, uint8  porcentaje)internal pure returns(uint[] memory){
        for(uint i= 0; i < arr.length; i++){
            arr[i] = arr[i]* (100+porcentaje) /100;
        }
        return arr;
    }
}