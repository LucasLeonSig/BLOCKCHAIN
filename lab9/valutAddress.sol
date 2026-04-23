// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26; 
import "hardhat/console.sol";

/*
 * CryptoVault contract: A service for storing Ether.
 */
contract CryptoVault1 {
    address public owner;      // Contract owner.

    uint8 prcFee;              // Percentage to be subtracted from
                               // deposited amounts to charge fees. A
                               // uint8 is used to represent
                               // percentage with two decimal
                               // digits. E.g, a value of 50 means a
                               // percentage of 0.50% 

    uint public collectedFees; // Amount of the balance that
                               // corresponds to fees.

    mapping (address => uint256) public accounts;

    modifier onlyOwner() {
        require(msg.sender == owner,"You are not the contract owner!");
        _;
    }

    // Constructor sets the owner of this contract and an initial
    // value for prcFee.
    constructor(uint8 _prcFee) {
        owner = msg.sender;
        prcFee = _prcFee;
    }

    // deposit allows clients to deposit amounts of Ether. A percentage
    // of the deposited amount is set aside as a fee for using this
    // vault. 
    function deposit() external payable{
        require (msg.value >= 100, "Insufficient deposit");
        uint fee = msg.value * prcFee / 10000; // two decimal digits
        accounts[msg.sender] += msg.value - fee;
        collectedFees += fee;
    }

    // withdraw allows clients to recover part of the amounts deposited
    // in this vault.
    function withdraw(uint _amount) external {
        require (accounts[msg.sender] >= _amount, "Insufficient funds");
        accounts[msg.sender] -= _amount;
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send funds");
    }

    // withdrawAll is similar to withdraw, but withdrawing all Ether
    // deposited by a client.
    function withdrawAll() external {
        uint amount = accounts[msg.sender];
        require (amount > 0, "Insufficient funds");
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send funds");
        accounts[msg.sender] = 0;
    }

    // collectFees is used by the contract owner to transfer all fees
    // collected from clients so far.
    function collectFees() external onlyOwner {
        require (collectedFees > 0, "No fees collected");
        (bool sent, ) = owner.call{value: collectedFees}("");
        require(sent, "Failed to send fees");
        collectedFees = 0;
    }

    function balanceOf(address _owner) external view returns (uint) {
        return accounts[_owner];
    }
}
