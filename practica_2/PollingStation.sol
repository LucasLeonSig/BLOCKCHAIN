// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

abstract contract PollingStation  {
  bool public votingFinished;
 bool private votingOpen;
 address private presidente;
 constructor(address p){
    presidente = p;
    votingFinished = false;
    votingOpen = false;
 }


modifier presidenteValido (){
    require(presidente == msg.sender, "no es el presidente de la mesa");
   _;
}

modifier votoValido (){
    require( (votingOpen == true) && (votingFinished == false), "Votacion cerrada");
    _;
 }
 function openVoting() external presidenteValido{
    votingOpen = true;
 }

 function closeVoting() external presidenteValido {
    votingOpen = false;
    votingFinished = true;
 }

  function castVote(uint partidoId) virtual external;
 function getResults() virtual external view returns (uint[] memory);

}

