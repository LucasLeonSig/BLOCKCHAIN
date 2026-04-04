// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./TokenVotacion.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IExecutableProposal.sol";

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
        uint presupuesto_actual;
        address contrato; 
        mapping(address => uint) registro_votos;
        uint num_votos;
        address creador_propuesta;
        uint num_participantes;
    }


    uint private num_max_tokens;
    uint private precio_token; 
    uint private dinero_pres; //temporal
    uint[] private _idsPropuestasActivas;
    uint[] private _idsPropuestasAprobadas;
    uint[] private _idsPropuestasSignaling;
    mapping(uint => uint) private _indexPropuestasActivas;
    mapping(uint => uint) private _indexPropuestasAprobadas;
    mapping(uint => uint) private _indexPropuestasSignaling;

   mapping(address => uint) private _check_id;

    mapping(uint => sPropuesta) private propuestas;
    uint id_propuesta = 1;


    mapping(address =>bool) participantes;

    constructor(uint _precio_token, uint _num_max_tokens){

        //Llamamos al contrato con ERC20
        precio_token = _precio_token; //adjuntamos valores de parametros a variables del contrato. 
        num_max_tokens = _num_max_tokens;
        isOpen =false; //Por defecto votación cerrada
        owner = msg.sender; //El dueño del contrato lo establecemos como quien lo crea.
        TokenVotacion tv = new TokenVotacion(0,precio_token, num_max_tokens, this(address));
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
        //ERC20(contract_ERC20)._mint();
    }


    function removeParticipant() public {
        participantes[msg.sender] = false;
        //mas eficiente borrar yo creo pero por ahora lo dejo asi
    }

    function addProposal( string calldata titulo, string calldata descripcion,uint  presupuesto, address contrato) public returns(uint dir_contrato){
            require(_check_id[contrato] == 0, "Ya existe una propuesta asignada a ese contrato"); //Comprobación de unicidad para intentar evitar ataques DoS, aunque el atacante siempre podría crearse nuevas proposal con contratos nuevos. 
            
            sPropuesta storage p = propuestas[id_propuesta];   
            p.titulo = titulo;
            p.descripcion = descripcion;
            p.presupuesto = presupuesto;
            p.contrato = contrato;
            p.creador_propuesta = msg.sender;

            if(presupuesto != 0){ 
                _idsPropuestasActivas.push(id_propuesta); //si el presupuesto es distinto de 0 el contrato es de tipo financiación.length;
                _indexPropuestasActivas[id_propuesta] = _idsPropuestasActivas.length-1;
            }else{ 
                _idsPropuestasSignaling.push(id_propuesta);
                _indexPropuestasActivas[id_propuesta] = _idsPropuestasSignaling.length-1;
            }

            id_propuesta += 1; //sumamos uno al indice de propuestas.
            return id_propuesta-1;
    }

    function cancelProposal(uint id) public{
        require(propuestas[id].creador_propuesta == msg.sender , "Solo puede eliminar una propuesta su creador");
        require(_indexPropuestasAprobadas[id] == 0, "Tratando de eliminar una Proposal que ya ha sido aceptada");
        uint indice_borrar = _indexPropuestasActivas[id];
        delete _indexPropuestasActivas[id];
        _idsPropuestasActivas[indice_borrar] = _idsPropuestasActivas[_idsPropuestasActivas.length -1];
        _indexPropuestasActivas[_idsPropuestasActivas[indice_borrar]] = indice_borrar;
        _idsPropuestasActivas.pop();
        //DEVOLVER TOKENS A PROPIETARIOS
    }

    function buyTokens() public payable{
        //precio tokens 0?
        //directamente reenvío el dinero?
        ITokenVotacionFun(contract_ERC20).add_tokens(msg.sender);
    }
    
    function sellTokens(uint numTokensV) public payable{
        //precio tokens 0?
        //directamente reenvío el dinero?
        IERC20(contract_ERC20).sell_tokens(msg.sender , numTokensV);  
        //si me da error porque no tiene esos tokens?
        //enviamos dinero
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


//temporal preguntar como devolver datos
function getProposalInfo(uint id) public view returns (
    string memory titulo, 
    string memory descripcion, 
    address creador, 
    uint numVotos
) {
    require(id > 0 && id < id_propuesta, "ID de propuesta no existe");

    sPropuesta storage p = propuestas[id];   

    return (
        p.titulo,
        p.descripcion,
        p.creador_propuesta, 
        p.num_votos
    );
}

    function stake(uint id, uint num_votos) public payable {
        uint num_tokens = num_votos * num_votos;
        require(num_votos > 0, "No se puede votar con 0 votos"); //requisito para no consumir gas más adelante.
        require(IERC20(contract_ERC20).allowance(msg.sender,address(this)) >= num_tokens,"No se ha autorizado a transferir tantos tokens");
        IERC20(contract_ERC20).transferFrom(msg.sender, address(this), num_tokens);
        if(propuestas[id].registro_votos[msg.sender] == 0) propuestas[id].num_participantes +=1;
        propuestas[id].num_votos += num_votos;
        propuestas[id].registro_votos[msg.sender] += num_votos;
        propuestas[id].presupuesto_actual += num_tokens * precio_token;
    }

    function withdrawFromProposal(uint num_votos, uint id) votacionAbierta public { //deduzco que la votación tendrá que estar abierta para sacar votos.
        require(_indexPropuestasActivas[id] != 0 || _indexPropuestasSignaling[id] != 0, "La propuesta tiene que estar abierta");
        uint num_votos_t = propuestas[id].registro_votos[msg.sender] ;
        require(num_votos_t >= num_votos, "Se quieren sacar mas votos de los que hay");
        uint token_salir = num_votos_t * num_votos_t - num_votos*num_votos;
        //IERC20(contract_ERC20).approve(msg.sender,token_salir);
        IERC20(contract_ERC20).transfer(msg.sender, token_salir);
        propuestas[id].num_votos -= num_votos;
        if(propuestas[id].registro_votos[msg.sender] == 0) propuestas[id].num_participantes -=1; //si el participante se queda con 0 votos, no se considera participante.
        propuestas[id].presupuesto_actual -= token_salir * precio_token; //quitamos del presupuesto actual los tokens que van a salir.

    }


    function _checkAndExecuteProposal(uint id)  internal {

    if(propuestas[id].presupuesto == 0) return;
    uint cociente = propuestas[id].presupuesto_actual*100/propuestas[id].presupuesto;
    uint factor_paren = 20 + cociente;

    uint threshold = (factor_paren* propuestas[id].num_votos)/100 + _idsPropuestasActivas.length; //cálculo umbral, multiplicamos antes de dividir y tenemos en cuenta la problemática de trabajar con decimales, por lo que multiplicamos y dividimos por 100.
    if(threshold > propuestas[id].num_votos && propuestas[id].presupuesto_actual >= propuestas[id].presupuesto){ //comprobación requisitos.
        IExecutableProposal(propuestas[id].contrato).executeProposal(id,propuestas[id].num_votos,propuestas[id].presupuesto_actual / precio_token);

     }
    }

}