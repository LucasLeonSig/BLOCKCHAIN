// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./TokenVotacion.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IExecutableProposal.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract QuadraticVoting{
   
    //MODIFIERS

    modifier existenciaId(uint id){
        require(propuestas[id].contrato != address(0)); //si la direccion del contrato a la que apunta es la nula decidimos que no existe
        _;
    }

    modifier votacionAbierta(){
        require(isOpen, "La votacion tiene que estar abierta");
        _;
    }

    modifier creadorVotacion(){
        require(msg.sender == owner, "Solo puede ejecutarlo el creador de la votacion");
        _;
    }

    modifier estaRegistrado(address user){
        require(participantes[user]);
        _;
    }

    //DATOS

    enum tEstado{
        PENDIENTE, 
        CANCELADO,
        CERRADO
    };
    
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
        uint ronda;
        bool extraible;
        tEstado estado;
    };


    address private owner;
    address private contract_ERC20;
    bool public isOpen;
    uint private num_max_tokens;
    uint private precio_token; 
    uint private dinero_pres; //temporal
    uint[] private _idsPropuestasActivas;
    uint[] private _idsPropuestasAprobadas;
    uint[] private _idsPropuestasSignaling;
    mapping(uint => uint) private _indexPropuestasActivas;
    mapping(uint => uint) private _indexPropuestasAprobadas;
    mapping(uint => uint) private _indexPropuestasSignaling;
    uint ronda; 
    mapping(address => bool) private _check_id; //Comprobamos si el contrato ya esta asociado. NO SE SI NECESARIO.
    mapping(uint => sPropuesta) private propuestas;
    uint id_propuesta = 1;
    mapping(address =>bool) participantes;
    uint num_participantes;

    constructor(uint _precio_token, uint _num_max_tokens){

        //Llamamos al contrato con ERC20
        precio_token = _precio_token; //adjuntamos valores de parametros a variables del contrato. 
        num_max_tokens = _num_max_tokens;
        isOpen =false; //Por defecto votación cerrada
        owner = msg.sender; //El dueño del contrato lo establecemos como quien lo crea.
        TokenVotacion tv = new TokenVotacion(0,precio_token, num_max_tokens, address(this));
        contract_ERC20 = address(tv);
    }

    //Condicion solo ejecutar una vez?
    function openVoting() public payable {
        require(msg.sender == owner, "Debe ser el propietario quien ejecute esta funcion");
        isOpen = true; //abrimos la votación
        dinero_pres += msg.value;
    }

    function addParticipant() public payable {
        require(participantes[msg.sender]);
        require(msg.value >= precio_token, "Se debe comprar como minimo un token");
        uint total_tokens = msg.value / precio_token;
        participantes[msg.sender] = true;
        num_participantes +=1;
        //ERC20(contract_ERC20)._mint();
    }


    function removeParticipant() public {
        require(participantes[msg.sender]);       
        participantes[msg.sender] = false;
        num_participantes -= 1;
        //mas eficiente borrar yo creo pero por ahora lo dejo asi
    }

    function addProposal( string calldata titulo, string calldata descripcion,uint  presupuesto, address contrato) external estaRegistrado(msg.sender)  returns(uint dir_contrato){
            require(IERC165(contrato).supportsInterface(0x986cc311),"El contrato no soporta la interfaz requerida"); //Comprobamos que el contrato soporta IExecutableProposal
            require(!_check_id[contrato], "Ya existe una propuesta asignada a ese contrato"); //Comprobación de unicidad para intentar evitar ataques DoS, aunque el atacante siempre podría crearse nuevas proposal con contratos nuevos. 

            _check_id[contrato] =true; //asignamos ya ese contrato y por ende lo ponemos a true.
            sPropuesta storage p = propuestas[id_propuesta];   
            p.titulo = titulo;
            p.descripcion = descripcion;
            p.presupuesto = presupuesto;
            p.contrato = contrato;
            p.creador_propuesta = msg.sender;
            p.ronda = ronda;
            p.extraible = true; // No se si es necesario porque claro si lo elimino de mi mapping de addresses?
            p.estado = PENDIENTE;

            
            if(presupuesto != 0){ 
                _idsPropuestasActivas.push(id_propuesta); //si el presupuesto es distinto de 0 el contrato es de tipo financiación;
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
        propuestas[id].estado = CANCELADO;

        //LOGICA ELIMINAR ELEMENTOS DE LA LISTA DE ACTIVAS
        uint indice_borrar = _indexPropuestasActivas[id];
        delete _indexPropuestasActivas[id];
        _idsPropuestasActivas[indice_borrar] = _idsPropuestasActivas[_idsPropuestasActivas.length -1];
        _indexPropuestasActivas[_idsPropuestasActivas[indice_borrar]] = indice_borrar;
        _idsPropuestasActivas.pop();
        //DEVOLVER TOKENS A PROPIETARIOS
         
    }

    function buyTokens(uint numTokensC) external estaRegistrado(msg.sender) payable{
        //precio tokens 0?
        //directamente reenvío el dinero?
        ITokenVotacionFun(contract_ERC20).add_tokens(msg.sender, numTokensC);
    }
    
    function sellTokens(uint numTokensV) public estaRegistrado(msg.sender) {
        //precio tokens 0?
        //directamente reenvío el dinero?
        ITokenVotacionFun(contract_ERC20).sell_tokens(msg.sender , numTokensV);  
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
function getProposalInfo(uint id) public view votacionAbierta existenciaId(id) returns (
    string memory titulo, 
    string memory descripcion, 
    address creador, 
    uint numVotos
) {
    sPropuesta storage p = propuestas[id];   

    return (
        p.titulo,
        p.descripcion,
        p.creador_propuesta, 
        p.num_votos
    );
}

    function stake(uint id, uint num_votos) external  estaRegistrado(msg.sender) existenciaId(id) {
        require(propuestas[id].estado == PENDIENTE & propuestas[id].ronda == ronda); //Comprobamos que la propuesta es votable.
        
        uint ant_votos = propuestas[id].registro_votos[msg.sender];
        uint num_tokens = (ant_votos + num_votos)**2 - ant_votos**2;
        require(num_votos > 0, "No se puede votar con 0 votos"); //requisito para no consumir gas más adelante.
        require(IERC20(contract_ERC20).allowance(msg.sender,address(this)) >= num_tokens,"No se ha autorizado a transferir tantos tokens");
        IERC20(contract_ERC20).transferFrom(msg.sender, address(this), num_tokens);
        
        if(propuestas[id].registro_votos[msg.sender] == 0) propuestas[id].num_participantes +=1;
       
        propuestas[id].num_votos += num_votos;
        propuestas[id].registro_votos[msg.sender] += num_votos;
        propuestas[id].presupuesto_actual += num_tokens * precio_token;
    }

    function withdrawFromProposal(uint num_votos, uint id) external existenciaId(id) votacionAbierta{ 
        

        uint num_votos_t = propuestas[id].registro_votos[msg.sender] ;
        require(num_votos_t >= num_votos, "Se quieren sacar mas votos de los que hay");
        
        //Cálculo del número de tokens a salir
        uint token_salir = num_votos_t**2 - (num_votos_t - num_votos)**2;        
        
        //transferimos
        IERC20(contract_ERC20).transfer(msg.sender, token_salir);
        
        //eliminamos de la cantidad de votos de la propuesta.
        propuestas[id].num_votos -= num_votos;
        
        if(propuestas[id].registro_votos[msg.sender] == 0) propuestas[id].num_participantes -=1; //si el participante se queda con 0 votos, no se considera participante.
        propuestas[id].presupuesto_actual -= token_salir * precio_token; //quitamos del presupuesto actual los tokens que van a salir.

    }


    function _checkAndExecuteProposal(uint id)  internal {

        if(propuestas[id].presupuesto == 0)  return; //Propuestas signaling

        //Cálculo umbral
        uint cociente = propuestas[id].presupuesto_actual*100 / propuestas[id].presupuesto;
        uint factor_paren = 20 + cociente;
        uint threshold = (factor_paren * num_participantes)/100 + _idsPropuestasActivas.length;

        //Si se cumplen las condiciones llamamos a la funcion executeProposal del contrato.
        if(threshold < propuestas[id].num_votos && propuestas[id].presupuesto_actual >= propuestas[id].presupuesto){ //comprobación requisitos.
            // Suponiendo que el Ether que quieres enviar es el presupuesto_actual
            IExecutableProposal(propuestas[id].contrato).executeProposal{value: propuestas[id].presupuesto_actual, gas:100000}( //llamamos y fijamos como maximo 100000 de gas tal y como establece el enunciado.
                id, propuestas[id].num_votos, propuestas[id].presupuesto_actual / precio_token
            );            
         //patron pull over push duda si lo dejo sobre id de propuesta.


            //El restante para el presupuesto total?
            dinero_pres +=  propuestas[id].presupuesto_actual - propuestas[id].presupuesto;      
            //borramos de propuesta activa de forma que el array se quede de la forma mas eficiente
            uint indice_borrar = _indexPropuestasActivas[id];
            delete _indexPropuestasActivas[id];
            _idsPropuestasActivas[indice_borrar] = _idsPropuestasActivas[_idsPropuestasActivas.length -1];
            _indexPropuestasActivas[_idsPropuestasActivas[indice_borrar]] = indice_borrar;
            _idsPropuestasActivas.pop();


            //añadimos a propuestas aprobadas
            _idsPropuestasAprobadas.push(id);
            _indexPropuestasAprobadas[_idsPropuestasAprobadas.length-1] = id;
        }
    }


    function closeVoting() external creadorVotacion {
        require(isOpen); //ponemos que este abierta para poder cerrarla para controlar el paso de rondas.
        //Cerramos la votación.
        isOpen = false;
        ronda +=1; //añadimos ronda para la siguiente vez que se abra.
    }

    function extraerTokens(uint id) existenciaId(id) external{
        require(propuestas[id].ronda < ronda & propuestas[id])
    }


}