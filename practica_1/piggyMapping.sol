// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

contract piggyMapping {

    struct Cliente {
        string name;
        uint cantidad;
    }
    
    mapping(address => Cliente) mapa;

    function addClient(string memory name) external payable {
        require(bytes(mapa[msg.sender].name).length == 0, "Already exists"); 
        require(bytes(name).length != 0, "Empty name");

        mapa[msg.sender] = Cliente({
            name: name,
            cantidad: msg.value
        });
    }   

    function deposit() external payable {
        require(bytes(mapa[msg.sender].name).length != 0, "Not exists");
        mapa[msg.sender].cantidad += msg.value;
    }

    function getBalance() external view returns (uint) {
        require(bytes(mapa[msg.sender].name).length != 0, "Not exists"); 
        return mapa[msg.sender].cantidad;
    }

    function withdraw(uint amountInWei) external {
        Cliente storage c = mapa[msg.sender];
        
        require(bytes(c.name).length != 0, "Not exists"); 
        require(amountInWei <= c.cantidad, "Insufficent balance");

        c.cantidad -= amountInWei;

        (bool success, ) = payable(msg.sender).call{value: amountInWei}("");
        require(success, "Error en la transaccion");
    }
}