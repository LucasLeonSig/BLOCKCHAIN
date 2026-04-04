// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

// 1. Ruta corregida (sin 'tree/master')
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//Añadimos interfaz 
interface ITokenVotacionFun {
    function add_tokens(address dir) external payable;
    function sell_tokens(address dir) external payable;

}


contract TokenVotacion is ERC20, ITokenVotacionFun {
    
    uint public precio_token;
    uint private _cap; //REVISAR LOGICA CAP DE EJEMPO
    uint public num_tokens;
    address private creador;
    constructor(uint256 initialSupply, uint _precio_token, uint cap, address _creador ) ERC20("Token de Votacion", "VOTE") {
        _mint(msg.sender, initialSupply);
        precio_token = _precio_token;
        num_tokens = 0;
        _cap = cap;
        creador = _creador;

    }

function add_tokens(address dir, uint numTokensV) external payable{
    require(msg.sender == creador, "El unico con capacidad para crear tokens es el contrato QuadraticVoting");
    _mint(dir, msg.value/precio_token);
}
function sell_tokens(address dir, uint numTokensV) external{
    require(msg.sender == creador, "El unico con capacidad para crear tokens es el contrato QuadraticVoting");
    _burn(dir, numTokensV);
    (bool success,) = dir.call{value:amount}("");
    require(success,"Error al enviar Ether.");

}



}