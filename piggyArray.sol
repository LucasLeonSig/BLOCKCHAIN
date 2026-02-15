// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;


contract PiggyArray{

    struct Cliente{
        string name;
        address addr;
        uint cantidad;
    }
    Cliente[] public array;

function clientIndex(address _address)internal view returns (uint){

        for( uint i = 0; i < array.length; i++){
            if(array[i].addr == _address) return i;
        }
        return array.length;
}

function addClient(string memory name) external payable {
    uint ind = clientIndex(msg.sender);
    require(ind == array.length,"Already exits");
    require( bytes(name).length != 0, "empty name");
    array.push(Cliente({
    name: name,
    addr :msg.sender,
    cantidad: msg.value
    }));
}

function deposit() external payable{
    uint ind = clientIndex(msg.sender);
    require(ind != array.length, "Not exists");
    array[ind].cantidad += msg.value;
}

function getBalance() external view returns (uint){
        uint ind = clientIndex(msg.sender);
        require(ind != array.length, "Not exists");
        return array[ind].cantidad;
}
function Withdraw(uint amountInWei)external {
        uint ind = clientIndex(msg.sender);
        require(ind != array.length, "Not exists");
        require(amountInWei <= array[ind].cantidad, "Insufficent balance");
        array[ind].cantidad -= amountInWei;
        (bool success, ) = payable(msg.sender).call{value: amountInWei}("");
        require(success, "Error en la transaccion");
}

    


}