// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./DhondtElectionRegion.sol";
import "./PollingStation.sol";


contract DhondtPollingStation is DhondtElectionRegion, PollingStation {
    constructor (address presidente, uint numPartidos, uint idRegion) DhondtElectionRegion(numPartidos, idRegion) PollingStation(presidente){}
    
    function castVote(uint partidoId)  external override votoValido{
        bool valido = registerVote(partidoId);
        require(valido, "Partido invalido");
        registerVote(partidoId);
    }

    function getResults() external override view returns(uint[] memory){
        require(votingFinished == true, "Hay una votacion abierta");
        return results;
    }
}

