// SPDX-License-Identifier: MIT
pragma solidity    ^0.8.5;
contract hello{
    event Print(string message);

    function hello_world() public{
        emit Print("Hello World");
    }
function factorial(uint n) public pure returns (uint) {
    uint result = 1;
    for (uint i = 1; i <= n; i++) {
        result *= i;
    }
    return result;
}

}

