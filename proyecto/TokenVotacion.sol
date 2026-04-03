// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

// 1. Ruta corregida (sin 'tree/master')
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenVotacion is ERC20 {
    
    constructor(uint256 initialSupply) ERC20("Token de Votacion", "VOTE") {
        _mint(msg.sender, initialSupply);
    }

function add_token() external{
    
}
}