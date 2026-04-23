// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

// 1. Ruta corregida (sin 'tree/master')
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



//Añadimos interfaz 
interface ITokenVotacionFun {
    function add_tokens(address dir,uint numTokensV) external;
    function sell_tokens(address dir, uint numTokensV) external;
    function burn_tokens(uint numTokensV) external;
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
        _mint(msg.sender, initialSupply);
        precio_token = _precio_token;
        num_tokens = 0;
        _cap = cap;
        creador = _creador;

    }

function add_tokens(address dir, uint numTokensV) external esCreador{
    require(totalSupply() + numTokensV <= _cap, "Cap de tokens superado");
    _mint(dir, numTokensV);
}

function sell_tokens(address dir, uint numTokensV) external esCreador{
    _burn(dir, numTokensV); 
}

function burn_tokens(uint numTokensV) external esCreador {
        _burn(msg.sender, numTokensV); 
    }

function aprobar(uint num_tokens) external{
    require(balanceOf(msg.sender) >= num_tokens); //comprobamos que intenta aprobar una cantidad de tokens menor a la que tiene
    _approve(msg.sender, creador, num_tokens);
}
}