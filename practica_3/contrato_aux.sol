// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

interface ERC721TokenReceiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4);
}

contract aux is ERC721TokenReceiver {

    uint private token_owner;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4) {
        token_owner = _tokenId;
        return ERC721TokenReceiver.onERC721Received.selector;
    }

    function getToken() public view returns (uint) {
        require(token_owner != 0, "No token");
        return token_owner;
    }
}