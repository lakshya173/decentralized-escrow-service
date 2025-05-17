// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title EscrowService
 * @dev A decentralized escrow service for secure transactions between buyers and sellers
 */
contract EscrowService {
    // Struct to store escrow details
    struct EscrowAgreement {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        bool isReleased;
        bool isRefunded;
        string description;
    }

    // Mapping of escrow ID to EscrowAgreement
    mapping(uint256 => EscrowAgreement) private agreements;
    
    // Counter for escrow IDs
    uint256 public nextEscrowId;
    
    // Events
    event EscrowCreated(uint256 escrowId, address buyer, address seller, address arbiter, uint256 amount, string description);
    event FundsReleased(uint256 escrowId, address releasedBy);
    event FundsRefunded(uint256 escrowId, address refundedBy);
    
    /**
     * @dev Creates a new escrow agreement between buyer and seller with an arbiter
     * @param _seller The address of the seller
     * @param _arbiter The address of the arbiter who can resolve disputes
     * @param _description Description of the goods or services
     */
    function createEscrow(address _seller, address _arbiter, string memory _description) external payable returns (uint256) {
        require(_seller != address(0), "Invalid seller address");
        require(_arbiter != address(0), "Invalid arbiter address");
        require(msg.value > 0, "Amount must be greater than 0");
        
        uint256 escrowId = nextEscrowId;
        
        agreements[escrowId] = EscrowAgreement({
            buyer: msg.sender,
            seller: _seller,
            arbiter: _arbiter,
            amount: msg.value,
            isReleased: false,
            isRefunded: false,
            description: _description
        });
        
        nextEscrowId++;
        
        emit EscrowCreated(escrowId, msg.sender, _seller, _arbiter, msg.value, _description);
        
        return escrowId;
    }
    
    /**
     * @dev Releases funds to the seller
     * @param _escrowId The ID of the escrow agreement
     */
    function releaseFunds(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        
        require(agreement.amount > 0, "Escrow does not exist");
        require(!agreement.isReleased && !agreement.isRefunded, "Funds already released or refunded");
        require(
            msg.sender == agreement.buyer || 
            msg.sender == agreement.arbiter, 
            "Only buyer or arbiter can release funds"
        );
        
        agreement.isReleased = true;
        
        emit FundsReleased(_escrowId, msg.sender);
        
        (bool success, ) = agreement.seller.call{value: agreement.amount}("");
        require(success, "Transfer to seller failed");
    }
    
    /**
     * @dev Refunds the buyer in case of disputes or cancellations
     * @param _escrowId The ID of the escrow agreement
     */
    function refundBuyer(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        
        require(agreement.amount > 0, "Escrow does not exist");
        require(!agreement.isReleased && !agreement.isRefunded, "Funds already released or refunded");
        require(
            msg.sender == agreement.seller || 
            msg.sender == agreement.arbiter, 
            "Only seller or arbiter can refund"
        );
        
        agreement.isRefunded = true;
        
        emit FundsRefunded(_escrowId, msg.sender);
        
        (bool success, ) = agreement.buyer.call{value: agreement.amount}("");
        require(success, "Transfer to buyer failed");
    }
    
    /**
     * @dev Get details of an escrow agreement
     * @param _escrowId The ID of the escrow agreement
     */
    function getEscrowDetails(uint256 _escrowId) external view returns (
        address buyer,
        address seller,
        address arbiter,
        uint256 amount,
        bool isReleased,
        bool isRefunded,
        string memory description
    ) {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.buyer != address(0), "Escrow does not exist");
        
        return (
            agreement.buyer,
            agreement.seller,
            agreement.arbiter,
            agreement.amount,
            agreement.isReleased,
            agreement.isRefunded,
            agreement.description
        );
    }
    
    /**
     * @dev Get basic agreement information by ID
     * @param _escrowId The ID of the escrow agreement to query
     */
    function getAgreement(uint256 _escrowId) external view returns (
        address buyer,
        address seller,
        uint256 amount,
        bool isReleased,
        bool isRefunded
    ) {
        EscrowAgreement storage agreement = agreements[_escrowId];
        return (
            agreement.buyer,
            agreement.seller,
            agreement.amount,
            agreement.isReleased,
            agreement.isRefunded
        );
    }
}
