// SPDX-License-Identifier: MIT
pragma solidity    ^0.8.5;

contract PiggyBank0{

    function deposit() external payable{}

    
    function withdraw(uint amountInWei) external{
        require(address(this).balance >= amountInWei, "Insufficient balance");
        (bool success, ) = payable(msg.sender).call{value: amountInWei}("");
        require(success, "Transfer failed");
    }

    function getBalance()external view returns (uint){
        return address(this).balance;
    }
}
