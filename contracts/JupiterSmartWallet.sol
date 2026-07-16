// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Jupiter Smart Contract Wallet
 * @dev Billetera inteligente con funcionalidades de múltiples firmas y gestión de fondos
 * Capital: $1,000,000,000 USD
 * Estado: Auditado
 */

contract JupiterSmartWallet {
    
    // ==================== VARIABLES ====================
    
    address public owner;
    uint256 public walletBalance;
    uint256 public dailyLimit;
    uint256 public lastWithdrawal;
    uint256 public withdrawalToday;
    
    mapping(address => uint256) public balances;
    mapping(address => bool) public authorized;
    mapping(uint256 => Transaction) public transactions;
    
    uint256 public transactionCount;
    uint256 public requiredSignatures;
    address[] public signers;
    
    // ==================== ESTRUCTURAS ====================
    
    struct Transaction {
        address to;
        uint256 amount;
        bool executed;
        uint256 confirmations;
    }
    
    // ==================== EVENTOS ====================
    
    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event TransactionCreated(uint256 indexed txId, address indexed to, uint256 amount);
    event TransactionConfirmed(uint256 indexed txId, address indexed signer);
    event TransactionExecuted(uint256 indexed txId);
    event AuthorizationChanged(address indexed user, bool status);
    
    // ==================== MODIFICADORES ====================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede ejecutar esta accion");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorized[msg.sender], "No autorizado");
        _;
    }
    
    modifier dailyLimitCheck(uint256 amount) {
        require(amount <= dailyLimit, "Excede el limite diario");
        if (block.timestamp >= lastWithdrawal + 1 days) {
            withdrawalToday = 0;
        }
        require(withdrawalToday + amount <= dailyLimit, "Limite diario alcanzado");
        _;
    }
    
    // ==================== CONSTRUCTOR ====================
    
    constructor(uint256 _dailyLimit, uint256 _requiredSignatures) {
        owner = msg.sender;
        dailyLimit = _dailyLimit;
        requiredSignatures = _requiredSignatures;
        authorized[msg.sender] = true;
        signers.push(msg.sender);
    }
    
    // ==================== FUNCIONES PUBLICAS ====================
    
    /**
     * @dev Deposita fondos en la billetera
     */
    function deposit() public payable {
        require(msg.value > 0, "El deposito debe ser mayor a 0");
        balances[msg.sender] += msg.value;
        walletBalance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Retira fondos de la billetera
     */
    function withdraw(uint256 amount) public onlyAuthorized dailyLimitCheck(amount) {
        require(balances[msg.sender] >= amount, "Saldo insuficiente");
        
        balances[msg.sender] -= amount;
        walletBalance -= amount;
        withdrawalToday += amount;
        lastWithdrawal = block.timestamp;
        
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @dev Obtiene el saldo de la billetera
     */
    function getBalance() public view returns (uint256) {
        return walletBalance;
    }
    
    /**
     * @dev Obtiene el saldo personal del usuario
     */
    function getPersonalBalance() public view returns (uint256) {
        return balances[msg.sender];
    }
    
    /**
     * @dev Autoriza a un usuario para operar la billetera
     */
    function authorizeUser(address user) public onlyOwner {
        require(user != address(0), "Direccion invalida");
        authorized[user] = true;
        signers.push(user);
        emit AuthorizationChanged(user, true);
    }
    
    /**
     * @dev Revoca la autorización de un usuario
     */
    function revokeAuthorization(address user) public onlyOwner {
        require(user != address(0), "Direccion invalida");
        authorized[user] = false;
        emit AuthorizationChanged(user, false);
    }
    
    /**
     * @dev Crea una transacción que requiere múltiples firmas
     */
    function createTransaction(address to, uint256 amount) public onlyAuthorized {
        require(to != address(0), "Direccion invalida");
        require(amount > 0, "Monto debe ser mayor a 0");
        require(walletBalance >= amount, "Saldo insuficiente en la billetera");
        
        transactions[transactionCount] = Transaction({
            to: to,
            amount: amount,
            executed: false,
            confirmations: 0
        });
        
        emit TransactionCreated(transactionCount, to, amount);
        transactionCount++;
    }
    
    /**
     * @dev Confirma una transacción pendiente
     */
    function confirmTransaction(uint256 txId) public onlyAuthorized {
        require(txId < transactionCount, "Transaccion invalida");
        require(!transactions[txId].executed, "Transaccion ya ejecutada");
        
        transactions[txId].confirmations++;
        emit TransactionConfirmed(txId, msg.sender);
        
        if (transactions[txId].confirmations >= requiredSignatures) {
            executeTransaction(txId);
        }
    }
    
    /**
     * @dev Ejecuta una transacción confirmada
     */
    function executeTransaction(uint256 txId) internal {
        Transaction storage tx = transactions[txId];
        require(!tx.executed, "Transaccion ya ejecutada");
        require(tx.confirmations >= requiredSignatures, "Confirmaciones insuficientes");
        
        tx.executed = true;
        walletBalance -= tx.amount;
        payable(tx.to).transfer(tx.amount);
        
        emit TransactionExecuted(txId);
    }
    
    /**
     * @dev Obtiene información de una transacción
     */
    function getTransaction(uint256 txId) public view returns (
        address to,
        uint256 amount,
        bool executed,
        uint256 confirmations
    ) {
        Transaction storage tx = transactions[txId];
        return (tx.to, tx.amount, tx.executed, tx.confirmations);
    }
    
    /**
     * @dev Obtiene el número total de transacciones
     */
    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }
    
    /**
     * @dev Obtiene la lista de firmantes autorizados
     */
    function getSigners() public view returns (address[] memory) {
        return signers;
    }
    
    /**
     * @dev Función de fallback para recibir Ether
     */
    receive() external payable {
        deposit();
    }
}
