// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

contract piggyMapping2 {

    struct Cliente {
        string name;
        uint cantidad;
    }
    
    mapping(address => Cliente) mapa;
    address[] addr;
 
    function addClient(string memory name) external payable {
        require(bytes(mapa[msg.sender].name).length == 0, "Already exists"); 
        require(bytes(name).length != 0, "Empty name");

        mapa[msg.sender] = Cliente({
            name: name,
            cantidad: msg.value
        });
        addr.push(msg.sender);
    }   

    function deposit() external payable {
        require(bytes(mapa[msg.sender].name).length != 0, "Not exists");
        mapa[msg.sender].cantidad += msg.value;
    }

    function getBalance() external view returns (uint) {
        require(bytes(mapa[msg.sender].name).length != 0, "Not exists"); // falta esto
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

    function checkBalances()external view returns (bool){
        uint suma = 0;
        for(uint i = 0; i < addr.length; i++){
            suma += mapa[addr[i]].cantidad;
        }
        return suma == address(this).balance;
    }
}