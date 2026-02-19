// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

contract DhondtElectionRegion{

    mapping(uint=> uint) private weights;
    
    uint private num_partidos;
    uint[] internal  results;
    uint private immutable regionId;

    constructor (uint n, uint rId ){
        num_partidos = n;
        regionId = rId;
        results = new uint[](n);
        savedRegionInfo();

    }

function savedRegionInfo() private{
    weights[28] = 1; // Madrid
    weights[8] = 1; // Barcelona
    weights[41] = 1; // Sevilla
    weights[44] = 5; // Teruel
    weights[42] = 5; // Soria
    weights[49] = 4; // Zamora
    weights[9] = 4; // Burgos
    weights[29] = 2; // Malaga
    }

    function registerVote(uint partido) internal returns (bool){
        if(partido >= num_partidos){
            return false;
        }
        results[partido] += weights[regionId];
        return true;
    }
}