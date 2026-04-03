// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./TokenVotacion.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract QuadraticVoting{
    bool public isOpen;
    modifier votacionAbierta(){
        require(isOpen, "La votacion tiene que estar abierta");
        _;
    }
    address private owner;
    address private contract_ERC20;

    struct sPropuesta{
        string titulo;
        string descripcion;
        uint presupuesto;
        address contrato; 
    }

    uint private num_max_tokens;
    uint private precio_token; //dudo si uint o tipo flotante
    uint private dinero_pres; //temporal
    uint[] private _idsPropuestasActivas;
    uint[] private _idsPropuestasAprobadas;
   uint[] private _idsPropuestasSignaling;
   mapping(uint => uint) private _indexPropuestasActivas;
   mapping(uint => uint) private _indexPropuestasAprobadas;
   mapping(uint => uint) private _indexPropuestasSignaling;
mapping(uint => address) private _creadorPropuestas;

   mapping(address => uint) private _check_id;

    sPropuesta[] private propuestas;


    mapping(address =>bool) participantes;

    constructor(uint _precio_token, uint _num_max_tokens){

        //Llamamos al contrato con ERC20
        precio_token = _precio_token; //adjuntamos valores de parametros a variables del contrato. 
        num_max_tokens = _num_max_tokens;
        isOpen =false; //Por defecto votación cerrada
        owner = msg.sender; //El dueño del contrato lo establecemos como quien lo crea.
        TokenVotacion tv = new TokenVotacion(0);
        contract_ERC20 = address(tv);

    }

    function openVoting() public payable {
        require(msg.sender == owner, "Debe ser el propietario quien ejecute esta funcion");   
        isOpen = true; //abrimos la votación
        dinero_pres += msg.value;
    }

    function addParticipant() public payable {
        require(msg.value >= precio_token, "Se debe comprar como minimo un token");
        uint total_tokens = msg.value / precio_token;
        participantes[msg.sender] = true;
    }


    function removeParticipant() public {
        participantes[msg.sender] = false;
        //mas eficiente borrar yo creo pero por ahora lo dejo asi
    }

    function addProposal( string calldata titulo, string calldata descripcion,uint  presupuesto, address contrato) public returns(uint dir_contrato){
            require(_check_id[contrato] == 0, "Ya existe una propuesta asignada a ese contrato"); //Comprobación de unicidad para intentar evitar ataques DoS, aunque el atacante siempre podría crearse nuevas proposal con contratos nuevos. 
            
            propuestas.push(sPropuesta({
                titulo:titulo,
                descripcion:descripcion,
                presupuesto: presupuesto,
                contrato: contrato
            }));

            _creadorPropuestas[propuestas.length-1] = msg.sender; //Añadimos a un map quien ha creado la propuesta para luego poder comporbarlo a la hora de eliminarla.

            if(presupuesto != 0){ 
                _idsPropuestasActivas.push(propuestas.length-1); //si el presupuesto es distinto de 0 el contrato es de tipo financiación.length;
                _indexPropuestasActivas[propuestas.length-1] = _idsPropuestasActivas.length-1;
            }else{ 
                _idsPropuestasSignaling.push(propuestas.length-1);
                _indexPropuestasActivas[propuestas.length-1] = _idsPropuestasSignaling.length-1;
            }

            return propuestas.length-1;
    }

    function cancelProposal(uint id) public{
        require(_creadorPropuestas[id] == msg.sender , "Solo puede eliminar una propuesta su creador");
        require(_indexPropuestasAprobadas[id] == 0, "Tratando de eliminar una Proposal que ya ha sido aceptada");
        uint indice_borrar = _indexPropuestasActivas[id];
        delete _indexPropuestasActivas[id];
        _idsPropuestasActivas[indice_borrar] = _idsPropuestasActivas[_idsPropuestasActivas.length -1];
        _indexPropuestasActivas[_idsPropuestasActivas[indice_borrar]] = indice_borrar;
        _idsPropuestasActivas.pop();
        //DEVOLVER TOKENS A PROPIETARIOS

    }

    function getERC20() public view returns(address){
        return contract_ERC20;
    }
    function getPendingProposals()public view votacionAbierta returns(uint[] memory){
        return _idsPropuestasActivas;
    }
    function getApprovedProposals() public view votacionAbierta returns(uint[] memory){
        return _idsPropuestasAprobadas;

    }
    function getSignalingProposals()  public view votacionAbierta returns(uint[] memory){
        return _idsPropuestasSignaling;
    }

    function getProposalInfo(uint id) public view votacionAbierta returns  (sPropuesta memory){
        require(id < propuestas.length || propuestas[id].contrato != address(0), "Id no existente"); //Si borrase yo alguna proposal devolvería 0, error también.
        return propuestas[id]; // deduzco que habria que hacer algun tipo de comprobación
    }

    function stake(uint id, uint num_votos) public payable {
        uint num_tokens = num_votos * num_votos;
        require(IERC20(contract_ERC20).allowance(msg.sender,address(this)) >= num_tokens,"No se ha autorizado a transferir tantos tokens");
        IERC20(contract_ERC20).transferFrom(msg.sender, address(this), num_tokens);
        
    }


}