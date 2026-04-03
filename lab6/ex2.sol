// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract ex2 {
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
assembly{
    let max, min := fmaxmin(arr.slot)
    maxmin := sub(max,min)
    function fmaxmin(slot) -> maxVal, minVal {
    let length := sload(slot)

    if iszero(length) { leave }

    mstore(0x00, slot)
    let dataStart := keccak256(0x00, 0x20)

    maxVal := sload(dataStart)
    minVal := maxVal

    for { let i := 1 } lt(i, length) { i := add(i, 1) } {
        let new_pos := add(dataStart, i)
        let dato := sload(new_pos)
        
        if gt(dato, maxVal) { maxVal := dato }
        if lt(dato, minVal) { minVal := dato } 
    }
}
}
}
}