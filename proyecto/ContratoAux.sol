// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "./IExecutableProposal.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
event PagoRecibido(address pagador, uint256 cantidad); //declaramos un evento para comprobar que efectivamente si que ha llegado el dinero.
event ConfirmacionDatos(uint proposalId, uint numVotes, uint numTokens);
contract ContratoAux is IExecutableProposal, ERC165 {
    
    // Implementas la función de tu interfaz
    function executeProposal(
        uint proposalId, 
        uint numVotes, 
        uint numTokens
    ) external payable override { 
        //emitimos eventos de confirmación tanto de pago como de datos.
        emit ConfirmacionDatos(proposalId, numVotes, numTokens);
        emit PagoRecibido(msg.sender, msg.value);
    }   

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return 
            interfaceId == type(IExecutableProposal).interfaceId || 
            super.supportsInterface(interfaceId);
    }
}