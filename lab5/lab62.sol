// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

contract lab6 {
    uint[] arr;
    uint sum;

    function generate(uint n) external {
        for (uint i = 0; i < n; i++) {
            arr.push(i * i);
        }
    }

    function computeSum() external {
        uint localSum = 0;
        uint length = arr.length;
        
        for (uint i = 0; i < length; i++) {
            localSum = localSum + arr[i];
        }
        
        sum = localSum;
    }
}