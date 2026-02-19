// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./DhondtPollingStation.sol";

contract Election {
    mapping(uint => DhondtPollingStation) private mapa;
    uint[] private regiones;
    uint private numPartidos;
    address private creador;
    mapping(address => bool) private votantes;

    constructor(uint n){
        creador = msg.sender;
        numPartidos = n;
    }  

    modifier onlyAuthority (){
        require(msg.sender == creador, "error no autorizado");
        _;
    }
    modifier freshId(uint regionId){
        require(address(mapa[regionId]) == address(0), "ya existe esa region");
        _;
    }

    modifier validId(uint regionId){
        require(address(mapa[regionId]) != address(0), "la region no existe");
        _;  
    }

    function createPollingStation(uint regionId, address presidente) external onlyAuthority freshId(regionId) returns(address) {
        DhondtPollingStation ps = new DhondtPollingStation(presidente, numPartidos,regionId);
        mapa[regionId] = ps;
        regiones.push(regionId);
        return address(ps);
    }

    function castVote(uint regionId, uint partidoId) external validId(regionId) {
        require(votantes[msg.sender] == false, "Ya ha votado");
        mapa[regionId].castVote(partidoId);
        votantes[msg.sender] = true;

    }

    function getResults() external view  returns (uint[] memory) {
        uint[] memory totales = new uint[](numPartidos);
        for (uint i = 0; i < regiones.length; i++) {
            uint idRegion = regiones[i];
            DhondtPollingStation ps = mapa[idRegion];

            uint[] memory resultadosRegion = ps.getResults();

            for (uint j = 0; j < numPartidos; j++) {
                totales[j] += resultadosRegion[j];
            }
        }
        
        return totales;
    }  
}