// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./ArrayUtils.sol";
contract MonsterTokens{
    using ArrayUtils for string[];
    using ArrayUtils for uint[];
    uint private token_id_actual = 10001; 

    struct Weapons{
        string[] names;
        uint[] firePowers;
    }

    struct Character{
        string name;
        Weapons weapons;
    }

    mapping(address => uint) private registry;
    mapping(uint => address) private owners;
    mapping(uint => address) private approvals;
    mapping(uint => Character) private tokens;
    uint creados= 0;

    address private contract_owner;

    uint256 public constant FEE = 1000;

    constructor(){
        contract_owner = msg.sender;
    }


    function createNewToken(string calldata nombre) external payable returns(uint){
        require(msg.value >= FEE, "Insuffcient funds");

        registry[msg.sender] +=1;
        owners[token_id_actual] = msg.sender;
        Character memory c = Character({
            name:nombre,
            weapons: Weapons({
                            names: new string[](0),
                            firePowers: new uint[](0)
                            })

            });
        creados += 1;
        tokens[token_id_actual] = c;
        token_id_actual +=1;
        return token_id_actual -1;
    }

    function removeMonsterToken(uint token_id_u) external payable {
        require(owners[token_id_u] != address(0) && owners[token_id_u] == msg.sender , "unauthorized access");
        (bool exito, ) = payable(msg.sender).call{value:1000}("");
        require(exito, "fallo en el pago");
        creados -= 1;
        registry[msg.sender] -= 1;
        delete owners[token_id_u];
        delete approvals[token_id_u];
        delete tokens[token_id_u];

    } 

    function addWeapon(uint token_id_p, string calldata nombre_arma, uint fire_power) payable external {
        require(approvals[token_id_p] == msg.sender || owners[token_id_p] == msg.sender, "Unauthorized access");
        require(bytes(tokens[token_id_p].name).length == 0, "Unauthorized access");
        require(msg.value >= fire_power * 2**tokens[token_id_p].weapons.names.length,"Not enough money");
        bool existe = tokens[token_id_p].weapons.names.contains(nombre_arma);
        require(!existe, "Already exists");
        tokens[token_id_p].weapons.names.push(nombre_arma);
        tokens[token_id_p].weapons.firePowers.push(fire_power);


    }


    function incrementFirePower(uint token_id_p, uint8 incr) payable external {
        require(approvals[token_id_p] == msg.sender || owners[token_id_p] == msg.sender, "Unauthorized access");
        require(msg.value >= incr ** 2, "Not enough money");    
        tokens[token_id_p].weapons.firePowers.increment(incr);

    }


    function collectProfits() external  payable{
        require(msg.sender == contract_owner, "Unauthorized acccess");
        (bool success, ) = payable(msg.sender).call{value:address(this).balance - creados * FEE}("");
    }


    function approve(address approved, uint256 tokenId)external payable{
        require(owners[tokenId] == msg.sender, "Unauthorized Access");
        require(approved != address(0), "Empty address");

        approvals[tokenId] = approved;
        require(msg.value >= tokens[tokenId].weapons.firePowers.sum(), "Not enough funds");

        //EVENTO?
    }

    function transferFrom(address from, address to, uint256 tokenId)external
    payable{
            require(owners[tokenId] == from || approvals[tokenId] == from, "Unauthorized Access");
            require(msg.value >= tokens[tokenId].weapons.firePowers.sum(), "Not enough funds");
            registry[owners[tokenId]] -= 1;
            registry[to] -= 1;
            owners[tokenId] = to;
            approvals[tokenId] = address(0);  
    }

    function balanceOf(address owner)external view returns (uint256){
        return registry[owner];
    }

    function ownerOf(uint256 tokenId)external view returns (address){
        address add = owners[tokenId];
        if(add == address(0)) revert("Invalid address");
        return add;
    }

    function getApproved(uint256 tokenId)external view returns (address){
        require(bytes(tokens[tokenId].name) != 0 , "Invalid token");
        return approvals[tokenId];
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external payable{
        
}


}