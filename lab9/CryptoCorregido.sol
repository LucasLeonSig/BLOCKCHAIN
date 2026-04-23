// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0; 

contract CryptoVault {
    address public owner;      
    uint public collectedFees; 
    address tLib;              
    uint8 prcFee;              
    mapping (address => uint256) public accounts;

    constructor(address _vaultLib, uint8 _prcFee) public {
        tLib = _vaultLib;
        prcFee = _prcFee;
        (bool success,) = tLib.delegatecall(abi.encodeWithSignature("init(address)",msg.sender));
        require(success,"delegatecall failed");
    }

    function deposit() public payable{
        require (msg.value >= 100, "Insufficient deposit");
        uint fee = msg.value * prcFee / 10000; 
        accounts[msg.sender] += msg.value - fee;
        collectedFees += fee;
    }

    function withdraw(uint _amount) public {
        //Se compara directamente el saldo con la cantidad a retirar 
        // para evitar que la resta aritmética provoque un underflow malicioso.
        require (accounts[msg.sender] >= _amount, "Insufficient funds"); 
        
        accounts[msg.sender] -= _amount;
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send funds");
    }

    function withdrawAll() public {
        uint amount = accounts[msg.sender];
        require (amount > 0, "Insufficient funds");
        accounts[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send funds");
    }

    fallback () external payable {
        (bool success,) = tLib.delegatecall(msg.data);
        require(success,"delegatecall failed");
    }
    
    receive () external payable {
        (bool success,) = tLib.delegatecall(msg.data);
        require(success,"delegatecall failed");
    }
}

contract VaultLib {
    address public owner;
    uint public collectedFees; 
    address this_tLib;         

    modifier onlyOwner() {
        require(msg.sender == owner,"You are not the contract owner!");
        _;
    }

    function init(address _owner) public {
        // Impedir reinicialización asegurando que la función solo 
        // pueda ejecutarse si la variable 'owner' está vacía (address(0)).
        require(owner == address(0), "El contrato ya ha sido inicializado"); 
        owner = _owner;
    }

    function collectFees() external onlyOwner {
        require (collectedFees > 0, "No fees collected");
        uint fees = collectedFees;
        collectedFees = 0;
        (bool sent, ) = owner.call{value: fees}("");
        require(sent, "Failed to send fees");
    }

    function setVaultLib(address _tLib) external onlyOwner {
        this_tLib = _tLib;
    }

    fallback () external payable {
        revert("Calling a non-existent function!");
    }

    receive () external payable {
        revert("This contract does not accept transfers with empty call data");
    }
}