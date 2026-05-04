// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;



import "./TokenVotacion.sol";
import "./IExecutableProposal.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract QuadraticVoting {

    // -------------------------------------------------------------------------
    // MODIFICADORES
    // -------------------------------------------------------------------------

    /*
        Comprueba que la cuenta que llama al contrato está registrada como participante.
        Uso este modificador en las funciones donde solo tiene sentido que actúe alguien
        que forma parte del sistema.
    */
    modifier usuarioRegistrado() {
        require(participantes[msg.sender].registrado, "Usuario no registrado");
        _;
    }

    /*
        Una propuesta existe si su campo contrato no es la dirección nula.
        Esta comprobación es suficiente porque todas las propuestas deben tener asociado
        un contrato externo que implemente IExecutableProposal.
    */
    modifier existenciaId(uint id) {
        require(propuestas[id].contrato != address(0)); //si la direccion del contrato a la que apunta es la nula decidimos que no existe
        _;
    }

    /*
        Algunas funciones solo deben poder ejecutarse durante una ronda de votación abierta,
        por ejemplo votar, crear propuestas o consultar los arrays de propuestas de la ronda.
    */
    modifier votacionAbierta() {
        require(isOpen, "La votacion tiene que estar abierta");
        _;
    }

    /*
        El creador del contrato es quien controla la apertura y cierre de rondas. Esto sigue
        el planteamiento del enunciado, donde el usuario que despliega el contrato es el
        autorizado para abrir y cerrar el periodo de votación.
    */
    modifier creadorVotacion() {
        require(msg.sender == owner, "Solo puede ejecutarlo el creador de la votacion");
        _;
    }

    /*
        Protección sencilla frente a reentrada mediante un lock manual.
    */
    modifier noReentrant() {
        require(!locked, "Reentrada no permitida");
        locked = true;
        _;
        locked = false;
    }


    // -------------------------------------------------------------------------
    // DATOS PRINCIPALES
    // -------------------------------------------------------------------------

    /*
        Estados posibles de una propuesta.

        ABIERTA: propuesta de financiación todavía pendiente.
        CANCELADO: propuesta cancelada por su creador.
        APROBADO: propuesta de financiación aprobada y ejecutada.
        SIGNALING: propuesta sin presupuesto asociado.
    */
    enum tEstado {
        ABIERTA,
        CANCELADO,
        APROBADO,
        SIGNALING
    }

    /*
        Información asociada a cada participante.

        No se mantiene un contador histórico de participantes para el umbral. En su lugar,
        se contabiliza únicamente la participación en la ronda actual. Esto evita que usuarios
        registrados en rondas anteriores afecten a votaciones posteriores sin intervenir en ellas.

        registrado:
            indica si el usuario está actualmente dado de alta.

        Un usuario eliminado sigue contando para el umbral si fue contabilizado en la
        ronda actual y mantiene votos activos.

        ultimaRondaContabilizada:
            última ronda en la que este usuario ha sido contado dentro de num_participantes.

        votosActivosRonda:
            número total de votos que mantiene activos el usuario en la ronda actual.
    */
    struct InfoParticipante {
        bool registrado;
        uint32 ultimaRondaContabilizada;
        uint64 votosActivosRonda;
    }

    /*
        Información almacenada para cada propuesta.

        El orden de los campos se ha escogido intentando aprovechar el empaquetado de storage
        de Solidity. Por ejemplo, address + enum + bool + uint32 pueden compartir mejor los
        slots de almacenamiento que si todos los campos estuvieran desordenados.

        registro_votos guarda cuántos votos ha depositado cada usuario en esta propuesta.
        No se puede devolver un mapping desde una función, por eso se consulta de forma
        indirecta a través de las operaciones de voto y retirada.
    */
    struct sPropuesta {
        address creador_propuesta;
        tEstado estado;
        bool exec;
        uint32 ronda;
        uint32 indice;

        address contrato;
        uint96 presupuesto;

        uint96 presupuesto_actual;
        uint96 num_votos;
        uint64 num_participantes;

        string titulo;
        string descripcion;

        mapping(address => uint) registro_votos;
    }

    /*
        Variables generales del contrato.

        owner:
            cuenta que despliega QuadraticVoting.

        isOpen:
            indica si hay una ronda de votación abierta.

        locked:
            variable usada por el modificador noReentrant.

        contract_ERC20:
            dirección del contrato TokenVotacion creado en el constructor.
    */
    address private owner;
    bool public isOpen;
    bool private locked;

    address private contract_ERC20;

    /*
        Parámetros económicos del sistema.

        num_max_tokens:
            máximo de tokens que se podrán emitir.

        precio_token:
            precio en Wei de cada token.

        dinero_pres:
            presupuesto global disponible para financiar propuestas de la ronda.
            Este valor aumenta con el presupuesto inicial y con los tokens consumidos en
            propuestas aprobadas, y disminuye cuando se financia una propuesta.
    */
    uint private num_max_tokens;
    uint private precio_token;
    uint private dinero_pres; 

    /*
        Identificadores y control de ronda.

        id_propuesta empieza en 1 para reservar el valor 0 como "no existente".
        num_participantes se refiere SOLO a la ronda actual.
        ronda empieza en 1 y se incrementa al cerrar la votación.
    */
    uint64 private id_propuesta = 1;
    uint64 private num_participantes;
    uint32 private ronda = 1;

    /*
        Arrays auxiliares para consultar propuestas según su estado/tipo.

        Para eliminar elementos de estos arrays se usa swap + pop, evitando desplazamientos
        lineales y manteniendo coste O(1).
    */
    uint[] private _idsPropuestasActivas;
    uint[] private _idsPropuestasAprobadas;
    uint[] private _idsPropuestasSignaling;

    // Mappings
    mapping(uint => sPropuesta) private propuestas;
    mapping(address => InfoParticipante) private participantes;

    /*
        Eventos del sistema.

        Se emiten eventos en las operaciones importantes para facilitar la auditoría del
        contrato, la depuración en Remix y la posible integración con una interfaz web.
    */
    event VotingOpened(uint32 indexed ronda, uint presupuestoInicial, uint64 numParticipantes);
    event VotingClosed(uint32 indexed rondaCerrada, uint presupuestoDevuelto);
    event TokensAdded(address indexed participante, uint tokensComprados);
    event ParticipantRemoved(address indexed participante, bool mantieneConteoPorVotosActivos);
    event ProposalAdded(uint indexed id, address indexed creador, address indexed contrato, uint presupuesto);
    event ProposalCancelled(uint indexed id);
    event Voted(address indexed votante, uint indexed id, uint votos, uint tokens);
    event VotesWithdrawn(address indexed votante, uint indexed id, uint votos, uint tokens);
    event ProposalApproved(uint indexed id, uint votos, uint presupuesto, uint tokensConsumidos);
    event TokensExtracted(address indexed votante, uint indexed id, uint tokens);
    event SignalingExecuted(uint indexed id, uint votos, uint tokens);


    // -------------------------------------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------------------------------------

    constructor(uint _precio_token, uint _num_max_tokens) {
        require(_precio_token > 0, "El precio del token debe ser mayor que 0");
        require(_num_max_tokens > 0, "El maximo de tokens debe ser mayor que 0");

        //Llamamos al contrato con ERC20
        precio_token = _precio_token; //adjuntamos valores de parametros a variables del contrato. 
        num_max_tokens = _num_max_tokens;
        isOpen = false; //Por defecto votación cerrada
        owner = msg.sender; //El dueño del contrato lo establecemos como quien lo crea.

        /*
            Se despliega el token ERC20 desde el propio contrato de votación.

            El cuarto parámetro es address(this), de modo que TokenVotacion reconoce a este
            contrato QuadraticVoting como el único autorizado para acuñar y quemar tokens
            mediante las funciones específicas del sistema.
        */
        TokenVotacion tv = new TokenVotacion(0, precio_token, num_max_tokens, address(this));
        contract_ERC20 = address(tv);
    }


    // -------------------------------------------------------------------------
    // GESTIÓN DEL CONTADOR DE PARTICIPANTES DE RONDA
    // -------------------------------------------------------------------------

    /*
        Contabiliza a un usuario como participante de la ronda actual si todavía no había sido
        contado en esta ronda.

        Esta función es importante porque evita arrastrar participantes históricos. Un usuario
        registrado en una ronda anterior no cuenta automáticamente en la siguiente: solo cuenta
        si interviene en la ronda actual, por ejemplo registrándose, comprando tokens, creando
        una propuesta o votando.
    */
    function _contabilizarParticipanteRonda(address participante) internal {
        InfoParticipante storage info = participantes[participante];

        // Solo contamos participantes de la ronda actual. No se arrastra ningun contador
        // historico de rondas anteriores.
        if (info.ultimaRondaContabilizada < ronda) {
            require(num_participantes < type(uint64).max, "Demasiados participantes");
            info.ultimaRondaContabilizada = ronda;
            info.votosActivosRonda = 0;
            num_participantes += 1;
        }
    }


    // -------------------------------------------------------------------------
    // APERTURA DE VOTACIÓN
    // -------------------------------------------------------------------------

    function openVoting() public payable creadorVotacion {
        require(!isOpen, "La votacion ya esta abierta");
        require(msg.value > 0, "Debe enviarse presupuesto inicial");

        isOpen = true; //abrimos la votación
        dinero_pres += msg.value;

        /*
            El número de participantes empieza en cero en cada ronda.

            Esto es una decisión de diseño relevante: se consideran únicamente los usuarios que
            intervienen en la ronda actual, no los registrados en rondas anteriores.
        */
        num_participantes = 0; //solo se cuentan los participantes que intervienen en la ronda actual

        //Nos aseguramos de que están vacios en el caso de que se hubiera abierto antes
        delete _idsPropuestasActivas;
        delete _idsPropuestasAprobadas;
        delete _idsPropuestasSignaling;

        emit VotingOpened(ronda, msg.value, num_participantes);
    }


    // -------------------------------------------------------------------------
    // PARTICIPANTES Y TOKENS
    // -------------------------------------------------------------------------

    /*
        Inscripción de participantes.

        Un usuario puede registrarse enviando Ether para comprar al menos un token. Si se
        registra durante una ronda abierta, pasa a contar como participante de esa ronda.
    */
    function addParticipant() public payable noReentrant {
        InfoParticipante storage info = participantes[msg.sender];

        require(!info.registrado); //comprobación el participante no esta borrado
        require(msg.value >= precio_token, "Se debe comprar como minimo un token");
        require(msg.value % precio_token == 0, "El Ether debe ser multiplo del precio del token");

        uint total_tokens = msg.value / precio_token;

        info.registrado = true;

        if (isOpen) {
            // Si se registra durante una ronda abierta, cuenta en esa ronda.
            // _contabilizarParticipanteRonda evita sumarlo dos veces si ya estaba
            // contabilizado porque se habia dado de baja manteniendo votos activos.
            _contabilizarParticipanteRonda(msg.sender);
        }

        ITokenVotacionFun(contract_ERC20).add_tokens(msg.sender, total_tokens); //enviamos tokens
        emit TokensAdded(msg.sender, total_tokens);
    }

    /*
        Baja de un participante.

        Si el usuario no tiene votos activos en la ronda actual, deja de contar para el umbral.
        Si sí tiene votos activos, se mantiene en el contador hasta que retire sus votos. Así
        se evita que pueda manipular el umbral eliminándose después de votar.
    */
    function removeParticipant() public usuarioRegistrado {
        InfoParticipante storage info = participantes[msg.sender];

        info.registrado = false;

        bool mantieneConteo = false;

        if (isOpen && info.ultimaRondaContabilizada == ronda) {
            // Si el participante ha votado en esta ronda y mantiene votos activos, sigue contando
            // para que no pueda manipular el umbral eliminandose despues de votar.
            if (info.votosActivosRonda > 0) {
                mantieneConteo = true;
            } else {
                num_participantes -= 1;
                info.ultimaRondaContabilizada = 0;
            }
        }

        emit ParticipantRemoved(msg.sender, mantieneConteo);
    }

    /*
        Compra adicional de tokens.

        Si la compra se realiza durante una ronda abierta, también se considera una forma de
        participar en la ronda actual, por lo que se contabiliza al usuario si todavía no lo
        estaba.
    */
    function buyTokens(uint numTokensC) public usuarioRegistrado payable noReentrant {
        require(numTokensC > 0, "Debe comprarse al menos un token");
        require(precio_token * numTokensC == msg.value, "Importe incorrecto");

        if (isOpen) {
            _contabilizarParticipanteRonda(msg.sender);
        }

        ITokenVotacionFun(contract_ERC20).add_tokens(msg.sender, numTokensC);
        emit TokensAdded(msg.sender, numTokensC);
    }

    /*
        Venta de tokens no comprometidos.

        Antes de quemar tokens se comprueba en TokenVotacion que el participante dispone de
        tokens realmente libres, es decir, que no están ya comprometidos mediante allowances.
    */
    function sellTokens(uint numTokensV) public usuarioRegistrado noReentrant {
        require(numTokensV > 0, "Debe venderse al menos un token");
            require(address(this).balance >= numTokensV * precio_token, "Fondos insuficientes");
        require(ITokenVotacionFun(contract_ERC20).disponibles_a_ceder(msg.sender, numTokensV));

        ITokenVotacionFun(contract_ERC20).sell_tokens(msg.sender, numTokensV);
        (bool success, ) = msg.sender.call{value: numTokensV * precio_token}("");
        require(success, "Error en la transferencia de Ether");       
        //enviamos dinero
    }


    // -------------------------------------------------------------------------
    // PROPUESTAS
    // -------------------------------------------------------------------------

    /*
        Creación de una propuesta.

        Solo puede realizarla un participante registrado y con la votación abierta. El contrato
        externo se valida mediante ERC165 para comprobar que implementa IExecutableProposal.
        Si presupuesto es cero, la propuesta se clasifica como signaling; si no, como propuesta
        de financiación.
    */
    function addProposal(
        string calldata titulo,
        string calldata descripcion,
        uint96 presupuesto,
        address contrato
    )
        external
        usuarioRegistrado
        votacionAbierta
        noReentrant
        returns (uint dir_contrato)
    {
        require(contrato != address(0), "Contrato de propuesta invalido");
        require(
            IERC165(contrato).supportsInterface(type(IExecutableProposal).interfaceId),
            "El contrato no soporta la interfaz requerida"
        ); //Comprobamos que el contrato soporta IExecutableProposal

        /*
            Crear una propuesta también se considera participación en la ronda actual.
        */
        _contabilizarParticipanteRonda(msg.sender);

        uint idActual = id_propuesta;
        sPropuesta storage p = propuestas[idActual];   

        p.titulo = titulo;
        p.descripcion = descripcion;
        p.presupuesto = presupuesto;
        p.contrato = contrato;
        p.creador_propuesta = msg.sender;
        p.ronda = ronda;
        require(id_propuesta +1 < type(uint64).max, "Demasiadas propuestas");

        if (presupuesto != 0) { 
            require(_idsPropuestasActivas.length <= type(uint32).max, "Demasiadas propuestas activas");
            _idsPropuestasActivas.push(idActual); //si el presupuesto es distinto de 0 el contrato es de tipo financiación;
            p.indice = uint32(_idsPropuestasActivas.length - 1);
            p.estado = tEstado.ABIERTA;
        } else { 
            require(_idsPropuestasSignaling.length <= type(uint32).max, "Demasiadas propuestas signaling");
            _idsPropuestasSignaling.push(idActual);
            p.estado = tEstado.SIGNALING;
            p.indice = uint32(_idsPropuestasSignaling.length - 1);
        }

        id_propuesta += 1; //sumamos uno al indice de propuestas.

        emit ProposalAdded(idActual, msg.sender, contrato, presupuesto);
        return idActual;
    }

    /*
        Cancelación de propuestas.

        Solo el creador de la propuesta puede cancelarla, y únicamente si pertenece a la ronda
        actual y no ha sido ya aprobada o cancelada. Los tokens no se devuelven aquí para no
        iterar sobre todos los votantes; se recuperan con extraerTokens.
    */
    function cancelProposal(uint id) public votacionAbierta existenciaId(id) {
        require(propuestas[id].creador_propuesta == msg.sender, "Solo puede eliminar una propuesta su creador");
        require(
            propuestas[id].estado != tEstado.APROBADO &&
            propuestas[id].ronda == ronda &&
            propuestas[id].estado != tEstado.CANCELADO,
            "Tratando de eliminar una Proposal indebida"
        );

        //LOGICA ELIMINAR ELEMENTOS DE LA LISTA DE ACTIVAS
        uint indice_borrar = propuestas[id].indice;

        if (propuestas[id].estado == tEstado.ABIERTA) {
            uint ultimoId = _idsPropuestasActivas[_idsPropuestasActivas.length - 1];
            _idsPropuestasActivas[indice_borrar] = ultimoId;
            propuestas[ultimoId].indice = uint32(indice_borrar);
            _idsPropuestasActivas.pop();
        } else {
            uint ultimoId = _idsPropuestasSignaling[_idsPropuestasSignaling.length - 1];
            _idsPropuestasSignaling[indice_borrar] = ultimoId;
            propuestas[ultimoId].indice = uint32(indice_borrar);
            _idsPropuestasSignaling.pop();
        }

        propuestas[id].estado = tEstado.CANCELADO; //ponemos estado en cancelado importante.

        emit ProposalCancelled(id);
    }


    // -------------------------------------------------------------------------
    // CONSULTAS
    // -------------------------------------------------------------------------

    function getERC20() public view returns(address) {
        return contract_ERC20;
    }

    function getPendingProposals() public view votacionAbierta returns(uint[] memory) {
        return _idsPropuestasActivas;
    }

    function getApprovedProposals() public view votacionAbierta returns(uint[] memory) {
        return _idsPropuestasAprobadas;
    }

    function getSignalingProposals() public view votacionAbierta returns(uint[] memory) {
        return _idsPropuestasSignaling;
    }

    /*
        Devuelve la información principal de una propuesta.

        No se devuelve el mapping registro_votos porque Solidity no permite devolver mappings.
        Para consultar la participación individual se puede razonar a partir de las funciones
        stake, withdrawFromProposal y extraerTokens.
    */
    function getProposalInfo(uint id) public view votacionAbierta existenciaId(id) returns (
        string memory titulo, 
        string memory descripcion, 
        address creador,
        address contrato,
        uint presupuesto,
        uint presupuestoActual,
        uint numVotos,
        uint numParticipantesPropuesta,
        tEstado estado,
        uint rondaPropuesta
    ) {

        sPropuesta storage p = propuestas[id];   

        return (
            p.titulo,
            p.descripcion,
            p.creador_propuesta,
            p.contrato,
            p.presupuesto,
            p.presupuesto_actual,
            p.num_votos,
            p.num_participantes,
            p.estado,
            p.ronda
        );
    }


    // -------------------------------------------------------------------------
    // VOTACIÓN CUADRÁTICA
    // -------------------------------------------------------------------------

    /*
        Deposita votos en una propuesta.

        El usuario debe haber aprobado previamente al contrato QuadraticVoting para mover sus
        tokens ERC20. El coste se calcula de forma marginal:
            coste = (votos_anteriores + votos_nuevos)^2 - votos_anteriores^2

        Esto permite votar varias veces a la misma propuesta manteniendo el coste total
        cuadrático.
    */
    function stake(uint id, uint num_votos)
        external
        usuarioRegistrado
        votacionAbierta
        existenciaId(id)
        noReentrant
    {
        require(
            (propuestas[id].estado == tEstado.ABIERTA || propuestas[id].estado == tEstado.SIGNALING) &&
            propuestas[id].ronda == ronda
        ); //Comprobamos que la propuesta es votable.

        require(num_votos > 0, "No se puede votar con 0 votos"); //requisito para no consumir gas más adelante.
        require(num_votos <= type(uint64).max, "Demasiados votos");

        sPropuesta storage p = propuestas[id];
        InfoParticipante storage info = participantes[msg.sender];

        /*
            Votar cuenta como participación en la ronda actual.
        */
        _contabilizarParticipanteRonda(msg.sender);

        uint ant_votos = p.registro_votos[msg.sender];
        uint num_tokens = (ant_votos + num_votos)**2 - ant_votos**2; 

        require(
            IERC20(contract_ERC20).allowance(msg.sender, address(this)) >= num_tokens,
            "No se ha autorizado a transferir tantos tokens"
        );

        require(IERC20(contract_ERC20).transferFrom(msg.sender, address(this), num_tokens),"transferencia fallida");

        if (p.registro_votos[msg.sender] == 0) {
            require(p.num_participantes < type(uint64).max, "Demasiados participantes en la propuesta");
            p.num_participantes += 1;
        }

        require(uint(p.num_votos) + num_votos <= type(uint96).max, "Demasiados votos en la propuesta");
        require(uint(p.presupuesto_actual) + num_tokens * precio_token <= type(uint96).max, "Presupuesto actual demasiado grande");
        require(uint(info.votosActivosRonda) + num_votos <= type(uint64).max, "Demasiados votos activos");

        p.num_votos += uint96(num_votos);
        p.registro_votos[msg.sender] += num_votos;
        p.presupuesto_actual += uint96(num_tokens * precio_token);
        info.votosActivosRonda += uint64(num_votos);

        emit Voted(msg.sender, id, num_votos, num_tokens);

        _checkAndExecuteProposal(id); //ejecutamos función auxiliar.
    }

    /*
        Retira votos de una propuesta no aprobada ni cancelada.

        El cálculo de tokens devueltos es el inverso del coste marginal:
            tokens = votos_actuales^2 - (votos_actuales - votos_retirados)^2
    */
    function withdrawFromProposal(uint num_votos, uint id)
        external
        existenciaId(id)
        votacionAbierta
        noReentrant
    { 
        sPropuesta storage p = propuestas[id];
        require(p.estado != tEstado.APROBADO && p.estado != tEstado.CANCELADO);
        require(num_votos > 0, "No se pueden retirar 0 votos");
        require(p.ronda == ronda, "La propuesta no pertenece a la ronda actual");

        InfoParticipante storage info = participantes[msg.sender];

        uint num_votos_t = p.registro_votos[msg.sender];

        require(num_votos_t >= num_votos, "Se quieren sacar mas votos de los que hay");
        require(info.ultimaRondaContabilizada == ronda && info.votosActivosRonda >= num_votos, "Votos activos insuficientes");

        //Cálculo del número de tokens a salir
        uint token_salir = num_votos_t**2 - (num_votos_t - num_votos)**2;        

        //eliminamos de la cantidad de votos de la propuesta.
        p.num_votos -= uint96(num_votos);
        p.registro_votos[msg.sender] -= num_votos;
        info.votosActivosRonda -= uint64(num_votos);

        if (p.registro_votos[msg.sender] == 0) {
            p.num_participantes -= 1; //si el participante se queda con 0 votos, no se considera participante de esa propuesta.
        }

        /*
            Si el usuario no esta registrado y ya no mantiene votos activos en la ronda
            actual, deja de contar para el umbral. Esta es la condicion que antes se
            marcaba con salioConVotosActivos, pero se puede deducir sin guardar otro flag.
        */
        if (
            isOpen &&
            info.ultimaRondaContabilizada == ronda &&
            !info.registrado &&
            info.votosActivosRonda == 0
        ) {
            num_participantes -= 1;
            info.ultimaRondaContabilizada = 0;
        }

        p.presupuesto_actual -= uint96(token_salir * precio_token); //quitamos del presupuesto actual los tokens que van a salir.

        //transferimos
        require(IERC20(contract_ERC20).transfer(msg.sender, token_salir),"transferencia fallida");   

        emit VotesWithdrawn(msg.sender, id, num_votos, token_salir);
    }


    // -------------------------------------------------------------------------
    // APROBACIÓN AUTOMÁTICA DE PROPUESTAS
    // -------------------------------------------------------------------------

    /*
        Comprueba si una propuesta de financiación debe aprobarse.

        Esta función se llama únicamente cuando una propuesta recibe votos. El umbral se calcula
        con la fórmula del enunciado, usando num_participantes de la ronda actual y el número de
        propuestas de financiación pendientes.

        Antes de llamar al contrato externo, se actualiza el estado interno. Esto sigue el patrón
        Checks-Effects-Interactions.
    */
    function _checkAndExecuteProposal(uint id) internal {
        sPropuesta storage p = propuestas[id];

        if (p.presupuesto == 0) return; //Propuestas signaling
        if (p.estado != tEstado.ABIERTA) return;

        require(dinero_pres > 0); //evitamos division entre cero

        //Cálculo umbral
        uint threshold =
            (
                20 * num_participantes +
                (uint(p.presupuesto) * 100 * num_participantes) / dinero_pres
            ) / 100
            + _idsPropuestasActivas.length;

        //Si se cumplen las condiciones llamamos a la funcion executeProposal del contrato.
        if (threshold < p.num_votos && dinero_pres >= p.presupuesto) {
            uint tokensConsumidos = uint(p.presupuesto_actual) / precio_token;

            dinero_pres = dinero_pres + uint(p.presupuesto_actual) - uint(p.presupuesto);      

            //borramos de propuesta activa de forma que el array se quede de la forma mas eficiente
            uint indice_borrar = p.indice;
            uint ultimoId = _idsPropuestasActivas[_idsPropuestasActivas.length - 1];

            _idsPropuestasActivas[indice_borrar] = ultimoId;
            propuestas[ultimoId].indice = uint32(indice_borrar);
            _idsPropuestasActivas.pop();

            //añadimos a propuestas aprobadas
            require(_idsPropuestasAprobadas.length <= type(uint32).max, "Demasiadas propuestas aprobadas");
            _idsPropuestasAprobadas.push(id);

            p.indice = uint32(_idsPropuestasAprobadas.length - 1);
            p.estado = tEstado.APROBADO;

            /*
                Los tokens usados para aprobar una propuesta se consumen. En este diseño se
                queman desde el balance del contrato de votación, porque stake los había movido
                previamente desde el votante hasta address(this).
            */
            ITokenVotacionFun(contract_ERC20).sell_tokens(address(this), tokensConsumidos);     

            emit ProposalApproved(id, p.num_votos, p.presupuesto, tokensConsumidos);

            //hacemos un try catch para comprobar que se ha ejecutado la propuesta.
            try IExecutableProposal(p.contrato).executeProposal{value: p.presupuesto, gas: 100000}(
                id,
                p.num_votos,
                tokensConsumidos
            ) {
            } catch {
                revert("Operacion fallida");
            }    
        }
    }


    // -------------------------------------------------------------------------
    // CIERRE DE VOTACIÓN
    // -------------------------------------------------------------------------

    /*
        Cierra la ronda actual.

        No se recorren propuestas ni participantes. Las devoluciones de tokens y la ejecución de
        propuestas de signaling quedan separadas en funciones pull, evitando que closeVoting
        dependa del tamaño de los datos almacenados.
    */
    function closeVoting() external creadorVotacion noReentrant {
        require(isOpen); //ponemos que este abierta para poder cerrarla para controlar el paso de rondas.
        require(ronda < type(uint32).max, "Demasiadas rondas");

        uint32 rondaCerrada = ronda;

        //Cerramos la votación.
        isOpen = false;
        ronda += 1; //añadimos ronda para la siguiente vez que se abra.
        num_participantes = 0;

        uint dinero_devolver = dinero_pres;
        dinero_pres = 0;

        (bool success, ) = owner.call{value: dinero_devolver}("");
        require(success);

        emit VotingClosed(rondaCerrada, dinero_devolver);
    }


    // -------------------------------------------------------------------------
    // PULL-OVER-PUSH: DEVOLUCIÓN DE TOKENS Y SIGNALING
    // -------------------------------------------------------------------------

    /*
        Permite recuperar tokens de propuestas canceladas o no aprobadas tras el cierre.

        Esta función no exige usuarioRegistrado de forma intencionada. Si un participante se
        ha dado de baja, conserva igualmente el derecho a recuperar los tokens bloqueados en
        sus votos.
    */
    function extraerTokens(uint id) existenciaId(id) external noReentrant {
        require(
            (propuestas[id].ronda < ronda && propuestas[id].estado != tEstado.APROBADO) ||
            propuestas[id].estado == tEstado.CANCELADO
        );

        sPropuesta storage p = propuestas[id];
        InfoParticipante storage info = participantes[msg.sender];

        uint votos = p.registro_votos[msg.sender];
        require(votos > 0, "No tiene suficientes votos");

        uint tokensADevolver = votos**2;

        p.num_votos -= uint96(votos);
        p.registro_votos[msg.sender] = 0;

        if (p.num_participantes > 0) {
            p.num_participantes -= 1;
        }

        if (info.ultimaRondaContabilizada == p.ronda && info.votosActivosRonda >= votos) {
            info.votosActivosRonda -= uint64(votos);
        }

        /*
            Si la propuesta es de la ronda actual, estaba cancelada y el usuario no esta
            registrado, deja de contar cuando ya no mantiene votos activos en esa ronda.
        */
        if (
            isOpen &&
            p.ronda == ronda &&
            info.ultimaRondaContabilizada == ronda &&
            !info.registrado &&
            info.votosActivosRonda == 0
        ) {
            num_participantes -= 1;
            info.ultimaRondaContabilizada = 0;
        }

        require(IERC20(contract_ERC20).transfer(msg.sender, tokensADevolver),"transferencia fallida");

        p.presupuesto_actual -= uint96(tokensADevolver * precio_token);

        emit TokensExtracted(msg.sender, id, tokensADevolver);
    }

    /*
        Ejecuta una propuesta de signaling una vez cerrada su ronda.

        Se ejecutan una a una para evitar que closeVoting tenga que hacer un bucle sobre todas
        las propuestas de signaling. Además, se marca exec antes de la llamada externa para
        impedir ejecuciones duplicadas.
    */
    function executeSignaling(uint id) external creadorVotacion existenciaId(id) noReentrant {
        require(propuestas[id].estado == tEstado.SIGNALING && propuestas[id].ronda < ronda && !propuestas[id].exec);

        sPropuesta storage p = propuestas[id];
        uint tokensUsados = uint(p.presupuesto_actual) / precio_token;

        p.exec = true;

        emit SignalingExecuted(id, p.num_votos, tokensUsados);

        try IExecutableProposal(p.contrato).executeProposal{value: 0, gas: 100000}(
            id,
            p.num_votos,
            tokensUsados
        ) {
        } catch {
            revert("Operacion signaling fallida");
        }    }
}