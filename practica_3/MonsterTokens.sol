// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "./ArrayUtils.sol";
import "./ERC721simplified.sol";

interface ERC721TokenReceiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4);
}

contract MonsterTokens is ERC721simplified {
    using ArrayUtils for string[];
    using ArrayUtils for uint[];

    uint private token_id_actual = 10001;

    struct Weapons {
        string[] names;
        uint[] firePowers;
    }

    struct Character {
        string name;
        Weapons weapons;
    }

    mapping(address => uint) private registry;
    mapping(uint => address) private owners;
    mapping(uint => address) private approvals;
    mapping(uint => Character) private tokens;
    uint private creados = 0;

    address private contract_owner;
    uint256 public constant FEE = 1000;

    constructor() {
        contract_owner = msg.sender;
    }

    function createNewToken(string calldata nombre) external payable returns (uint) {
        require(msg.value >= FEE, "Insufficient funds");

        registry[msg.sender] += 1;
        owners[token_id_actual] = msg.sender;
        tokens[token_id_actual].name = nombre;

        creados += 1;
        token_id_actual += 1;
        return token_id_actual - 1;
    }

    function removeMonsterToken(uint token_id_u) external payable {
        require(
            owners[token_id_u] != address(0) && owners[token_id_u] == msg.sender,
            "Unauthorized access"
        );

        creados -= 1;
        registry[msg.sender] -= 1;
        delete owners[token_id_u];
        delete approvals[token_id_u];
        delete tokens[token_id_u];

        (bool exito, ) = payable(msg.sender).call{value: FEE}("");
        require(exito, "Payment failed");
    }

    function addWeapon( uint token_id_p, string calldata nombre_arma, uint fire_power) external payable {
        require(
            approvals[token_id_p] == msg.sender || owners[token_id_p] == msg.sender,
            "Unauthorized access"
        );
        require(bytes(tokens[token_id_p].name).length != 0, "Invalid token");

        uint weaponIndex = tokens[token_id_p].weapons.names.length;
        require(
            msg.value >= fire_power * (2 ** weaponIndex),
            "Not enough money"
        );

        bool existe = tokens[token_id_p].weapons.names.contains(nombre_arma);
        require(!existe, "Already exists");

        tokens[token_id_p].weapons.names.push(nombre_arma);
        tokens[token_id_p].weapons.firePowers.push(fire_power);
    }

    function incrementFirePower(uint token_id_p, uint8 incr) external payable {
        require(
            approvals[token_id_p] == msg.sender || owners[token_id_p] == msg.sender,
            "Unauthorized access"
        );
        require(msg.value >= uint256(incr) ** 2, "Not enough money");

        tokens[token_id_p].weapons.firePowers.increment(incr);
    }

    function collectProfits() external {
        require(msg.sender == contract_owner, "Unauthorized access");
        uint profits = address(this).balance - creados * FEE;
        (bool success, ) = payable(msg.sender).call{value: profits}("");
        require(success, "Transfer failed");
    }


    function approve(address approved, uint256 tokenId) external payable override {
        require(owners[tokenId] == msg.sender, "Unauthorized access");
        require(approved != address(0) || approvals[tokenId] != address(0), "Nothing to approve");

        require(
            msg.value >= tokens[tokenId].weapons.firePowers.sum(),
            "Not enough funds"
        );

        approvals[tokenId] = approved;
        emit Approval(msg.sender, approved, tokenId);
    }

    function transferFrom(address from,address to, uint256 tokenId) external payable override {
        require(to != address(0), "Invalid recipient");
        require(
            owners[tokenId] == from &&
            (owners[tokenId] == msg.sender || approvals[tokenId] == msg.sender),
            "Unauthorized access"
        );
        require(
            msg.value >= tokens[tokenId].weapons.firePowers.sum(),
            "Not enough funds"
        );

        registry[owners[tokenId]] -= 1;
        registry[to] += 1;
        owners[tokenId] = to;
        approvals[tokenId] = address(0);

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom( address from, address to, uint256 tokenId) external payable override {
        require(to != address(0), "Invalid recipient");
        require(owners[tokenId] == from && (owners[tokenId] == msg.sender || approvals[tokenId] == msg.sender),
        "Unauthorized access");
        require( msg.value >= tokens[tokenId].weapons.firePowers.sum(),
        "Not enough funds"
        );

        if(to.code.length > 0){
             try ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, "") returns (bytes4 retval) {
                if (retval != ERC721TokenReceiver.onERC721Received.selector) {
                    revert("Token rejected");
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("Invalid reciever");
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
        


        registry[owners[tokenId]] -= 1;
        registry[to] += 1;
        owners[tokenId] = to;
        approvals[tokenId] = address(0);
         emit Transfer(from, to, tokenId);



    }

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "Invalid address");
        return registry[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address addr = owners[tokenId];
        require(addr != address(0), "Invalid token");
        return addr;
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        require(bytes(tokens[tokenId].name).length != 0, "Invalid token");
        return approvals[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if(type(ERC165).interfaceId == interfaceId || type(ERC721simplified).interfaceId == interfaceId)  return true;
        return false;
    
}

    receive() external payable {}
}