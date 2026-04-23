// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;
import "./TokenVotacion.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IExecutableProposal.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract QuadraticVoting{
   
    //MODIFIERS

    modifier usuarioRegistrado(){
        require(participantes[msg.sender]);
        _;
    }

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


    //DATOS

    enum tEstado{
        ABIERTA, 
        CANCELADO,
        APROBADO,
        SIGNALING
    }
    
    struct sPropuesta{
        bool extraible;
        uint presupuesto;
        uint presupuesto_actual;
        uint num_votos;
        string titulo;
        string descripcion;
        address contrato; 
        address creador_propuesta;
        uint num_participantes;
        uint ronda;
        uint indice;
        tEstado estado;
        mapping(address => uint) registro_votos;

    }


    address private owner;
    address private contract_ERC20;
    bool public isOpen;
    uint private num_max_tokens;
    uint private precio_token; 
    uint private dinero_pres; //temporal
    uint[] private _idsPropuestasActivas;
    uint[] private _idsPropuestasAprobadas;
    uint[] private _idsPropuestasSignaling;
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
    function openVoting() public payable creadorVotacion {
        require(!isOpen, "La votacion ya esta abierta");
        isOpen = true; //abrimos la votación
        dinero_pres += msg.value;

        //Nos aseguramos de que están vacios en el caso de que se hubiera abierto antes
        delete _idsPropuestasActivas;
        delete _idsPropuestasAprobadas;
        delete _idsPropuestasSignaling;
    }


    function addParticipant() public payable {
        require(!participantes[msg.sender]); //comprobación el participante no esta borrado
        require(msg.value >= precio_token, "Se debe comprar como minimo un token");
        uint total_tokens = msg.value / precio_token;
        participantes[msg.sender] = true;
        num_participantes +=1;
        ITokenVotacionFun(contract_ERC20).add_tokens(msg.sender, total_tokens); //enviamos tokens

    }


    function removeParticipant() public usuarioRegistrado{
        participantes[msg.sender] = false;
        num_participantes -= 1;
        //mas eficiente borrar yo creo pero por ahora lo dejo asi
    }

    function addProposal( string calldata titulo, string calldata descripcion,uint  presupuesto, address contrato) external usuarioRegistrado votacionAbierta returns(uint dir_contrato){
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

            
            if(presupuesto != 0){ 
                _idsPropuestasActivas.push(id_propuesta); //si el presupuesto es distinto de 0 el contrato es de tipo financiación;
                propuestas[id_propuesta].indice = _idsPropuestasActivas.length-1;
                propuestas[id_propuesta].estado = tEstado.ABIERTA;
            }else{ 
                _idsPropuestasSignaling.push(id_propuesta);
                propuestas[id_propuesta].estado = tEstado.SIGNALING;
                propuestas[id_propuesta].indice = _idsPropuestasSignaling.length-1;
            }

            id_propuesta += 1; //sumamos uno al indice de propuestas.
            return id_propuesta-1;
    }

    function cancelProposal(uint id) public votacionAbierta{
       
        require(propuestas[id].creador_propuesta == msg.sender , "Solo puede eliminar una propuesta su creador");
        require(propuestas[id].estado != tEstado.APROBADO && propuestas[id].ronda == ronda &&propuestas[id].estado != tEstado.CANCELADO , "Tratando de eliminar una Proposal indebida");
        propuestas[id].estado = tEstado.CANCELADO;

        //LOGICA ELIMINAR ELEMENTOS DE LA LISTA DE ACTIVAS
        uint indice_borrar = propuestas[id].indice;
        if(propuestas[id].estado == tEstado.ABIERTA){
        _idsPropuestasActivas[indice_borrar] = _idsPropuestasActivas[_idsPropuestasActivas.length -1];
        propuestas[_idsPropuestasActivas[indice_borrar]].indice = indice_borrar;
        _idsPropuestasActivas.pop();
        }else{
        _idsPropuestasSignaling[indice_borrar] = _idsPropuestasSignaling[_idsPropuestasActivas.length -1];
        propuestas[_idsPropuestasSignaling[indice_borrar]].indice = indice_borrar;
        _idsPropuestasSignaling.pop();

        }

        //PATRON PULL OVER PUSH PARA DEVOLVER TOKENS         
    }

    function buyTokens(uint numTokensC) public usuarioRegistrado payable{
        //precio tokens 0?
        //directamente reenvío el dinero?
        require(precio_token*numTokensC == msg.value);
        ITokenVotacionFun(contract_ERC20).add_tokens(msg.sender, numTokensC);
    }
    
    function sellTokens(uint numTokensV) public usuarioRegistrado {

        require(ITokenVotacionFun(contract_ERC20).disponibles_a_ceder(msg.sender, numTokensV));
        ITokenVotacionFun(contract_ERC20).sell_tokens(msg.sender , numTokensV);
        (bool success, ) = msg.sender.call{value: numTokensV * precio_token}("");
        require(success, "Error en la transferencia de Ether");        //si me da error porque no tiene esos tokens?
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

    function stake(uint id, uint num_votos) external  usuarioRegistrado existenciaId(id) {
        require(propuestas[id].estado == tEstado.ABIERTA && propuestas[id].ronda == ronda); //Comprobamos que la propuesta es votable.
        
        uint ant_votos = propuestas[id].registro_votos[msg.sender];
        uint num_tokens = (ant_votos + num_votos)**2 - ant_votos**2; //cuidado sobrepasar 
        require(num_votos > 0, "No se puede votar con 0 votos"); //requisito para no consumir gas más adelante.
        require(IERC20(contract_ERC20).allowance(msg.sender,address(this)) >= num_tokens,"No se ha autorizado a transferir tantos tokens");
        IERC20(contract_ERC20).transferFrom(msg.sender, address(this), num_tokens);
        
        if(propuestas[id].registro_votos[msg.sender] == 0) propuestas[id].num_participantes +=1;
       
        propuestas[id].num_votos += num_votos;
        propuestas[id].registro_votos[msg.sender] += num_votos;
        propuestas[id].presupuesto_actual += num_tokens * precio_token;
        _checkAndExecuteProposal(id); //ejecutamos función auxiliar.
    }

    function withdrawFromProposal(uint num_votos, uint id) external existenciaId(id) usuarioRegistrado votacionAbierta{ 
        require(propuestas[id].estado != tEstado.APROBADO && propuestas[id].estado != tEstado.SIGNALING);
        uint num_votos_t = propuestas[id].registro_votos[msg.sender] ;
        require(num_votos_t >= num_votos, "Se quieren sacar mas votos de los que hay");
        
        //Cálculo del número de tokens a salir
        uint token_salir = num_votos_t**2 - (num_votos_t - num_votos)**2;        
        
        //eliminamos de la cantidad de votos de la propuesta.
        propuestas[id].num_votos -= num_votos;
        propuestas[id].registro_votos[msg.sender] -= num_votos;
       
        //transferimos
        IERC20(contract_ERC20).transfer(msg.sender, token_salir);   

        if(propuestas[id].registro_votos[msg.sender] == 0) propuestas[id].num_participantes -=1; //si el participante se queda con 0 votos, no se considera participante.
        propuestas[id].presupuesto_actual -= token_salir * precio_token; //quitamos del presupuesto actual los tokens que van a salir.

    }

    function _checkAndExecuteProposal(uint id)  internal {

        if(propuestas[id].presupuesto == 0)  return; //Propuestas signaling

        //Cálculo umbral
        uint cociente = (propuestas[id].presupuesto * 100) / dinero_pres;
        uint factor_paren = 20 + cociente;
        uint threshold = (20 * num_participantes +  (propuestas[id].presupuesto * 100 * num_participantes) / dinero_pres) / 100 + _idsPropuestasActivas.length;
        //Si se cumplen las condiciones llamamos a la funcion executeProposal del contrato.
        if(threshold < propuestas[id].num_votos && propuestas[id].presupuesto_actual >= propuestas[id].presupuesto){ //comprobación requisitos.

            //El restante para el presupuesto total?
            dinero_pres +=  propuestas[id].presupuesto_actual - propuestas[id].presupuesto;      
            
            //borramos de propuesta activa de forma que el array se quede de la forma mas eficiente
            uint indice_borrar = propuestas[id].indice;
            _idsPropuestasActivas[indice_borrar] = _idsPropuestasActivas[_idsPropuestasActivas.length -1];
            propuestas[_idsPropuestasActivas[indice_borrar]].indice = indice_borrar;
            _idsPropuestasActivas.pop();
            
            //añadimos a propuestas aprobadas
            _idsPropuestasAprobadas.push(id);
            propuestas[id].indice = _idsPropuestasAprobadas.length-1;
            propuestas[id].estado = tEstado.APROBADO;


            // Suponiendo que el Ether que quieres enviar es el presupuesto_actual
            IExecutableProposal(propuestas[id].contrato).executeProposal{value: propuestas[id].presupuesto_actual, gas:100000}( //llamamos y fijamos como maximo 100000 de gas tal y como establece el enunciado.
                id, propuestas[id].num_votos, propuestas[id].presupuesto_actual / precio_token
            );     

            ITokenVotacionFun(contract_ERC20).burn_tokens(address(this),propuestas[id].num_votos ** 2) ;
     
        }
    }


    function closeVoting() external creadorVotacion {
        require(isOpen); //ponemos que este abierta para poder cerrarla para controlar el paso de rondas.
        //Cerramos la votación.
        isOpen = false;
        ronda +=1; //añadimos ronda para la siguiente vez que se abra.
    }

    //funcion de pull over push
    function extraerTokens(uint id) existenciaId(id) usuarioRegistrado external{
        require((propuestas[id].ronda < ronda && propuestas[id].estado != tEstado.APROBADO) || propuestas[id].estado == tEstado.CANCELADO);
        uint votos = propuestas[id].registro_votos[msg.sender];
        require(votos > 0);
        propuestas[id].num_votos -= votos;
        propuestas[id].registro_votos[msg.sender] = 0;
        IERC20(contract_ERC20).transfer(msg.sender,votos**2);
    }
}