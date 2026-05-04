// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IExecutableProposal is IERC165 {
    function executeProposal(
        uint proposalId,
        uint numVotes,
        uint numTokens
    ) external payable;
}