// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract ex3 {
uint[] public arr;
function generate(uint n) external {
// Populates the array with some weird small numbers.
    bytes32 b = keccak256("seed");
    delete arr;
    for (uint i = 0; i < n; i++) {
    uint8 number = uint8(b[i % 32]);
    arr.push(number);
    }
    }
function maxMinStorage() public view returns (uint maxmin){
    require(arr.length != 0, "longitud no valida");
    uint maxi = arr[0];
    uint mini = maxi;
    for(uint i = 1;i < arr.length;i++){
        uint dato = arr[i];
        if(dato > maxi) maxi = dato;
        if(dato < mini) mini = dato;
    }
    maxmin = maxi-mini;

}
}