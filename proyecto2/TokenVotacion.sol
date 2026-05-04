// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//Añadimos interfaz 
interface ITokenVotacionFun {
    function add_tokens(address dir,uint numTokensV) external;
    function sell_tokens(address dir, uint numTokensV) external;
    function disponibles_a_ceder(address user, uint num_tokens)  external view returns(bool);
}


contract TokenVotacion is ERC20, ITokenVotacionFun {
    


    uint public precio_token;
    uint private _cap; //REVISAR LOGICA CAP DE EJEMPLO
    uint public num_tokens;
    address private creador;

    modifier esCreador() {
            require(msg.sender == creador, "Solo QuadraticVoting puede ejecutar esto");
            _;
        }

    constructor(uint256 initialSupply, uint _precio_token, uint cap, address _creador ) ERC20("Token de Votacion", "VOTE") {
        require(_precio_token > 0, "El precio del token debe ser mayor que 0");
        require(cap > 0, "El maximo de tokens debe ser mayor que 0");
        require(_creador != address(0), "Creador invalido");

        _mint(msg.sender, initialSupply);
        precio_token = _precio_token;
        num_tokens = 0;
        _cap = cap;
        creador = _creador;

    }

function add_tokens(address dir, uint numTokensV) external esCreador{
    require(dir != address(0), "Direccion invalida");
    require(numTokensV > 0, "Debe mintearse al menos un token");
    require(totalSupply() + numTokensV <= _cap, "Cap de tokens superado");
    _mint(dir, numTokensV);
}

function sell_tokens(address dir, uint numTokensV) external esCreador{
    require(dir != address(0), "Direccion invalida");
    require(numTokensV > 0, "Debe quemarse al menos un token");
    require(balanceOf(dir) >= allowance(dir, creador) + numTokensV, "Tokens no disponibles para quemar");
    _burn(dir, numTokensV); 
}

function aprobar(uint num_tokens2) external{
    require(balanceOf(msg.sender) >= num_tokens2); //comprobamos que intenta aprobar una cantidad de tokens menor a la que tiene
    _approve(msg.sender, creador, num_tokens2);
}
function disponibles_a_ceder(address user, uint num_tokens2) esCreador external view returns(bool){
    return (balanceOf(user) >= allowance(user, creador) + num_tokens2);
}

}