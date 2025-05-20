// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EscrowService {
    struct EscrowAgreement {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        bool isReleased;
        bool isRefunded;
        string description;
    }

    mapping(uint256 => EscrowAgreement) private agreements;
    uint256 public nextEscrowId;

    // Track user involvement
    mapping(address => uint256[]) private userEscrows;

    event EscrowCreated(uint256 escrowId, address buyer, address seller, address arbiter, uint256 amount, string description);
    event FundsReleased(uint256 escrowId, address releasedBy);
    event FundsRefunded(uint256 escrowId, address refundedBy);
    event EscrowCancelled(uint256 escrowId, address cancelledBy);

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

        // Track user involvement
        userEscrows[msg.sender].push(escrowId);
        userEscrows[_seller].push(escrowId);
        userEscrows[_arbiter].push(escrowId);

        nextEscrowId++;

        emit EscrowCreated(escrowId, msg.sender, _seller, _arbiter, msg.value, _description);

        return escrowId;
    }

    function releaseFunds(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.amount > 0, "Escrow does not exist");
        require(!agreement.isReleased && !agreement.isRefunded, "Funds already finalized");
        require(msg.sender == agreement.buyer || msg.sender == agreement.arbiter, "Not authorized");

        agreement.isReleased = true;
        emit FundsReleased(_escrowId, msg.sender);

        (bool success, ) = agreement.seller.call{value: agreement.amount}("");
        require(success, "Transfer failed");
    }

    function refundBuyer(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.amount > 0, "Escrow does not exist");
        require(!agreement.isReleased && !agreement.isRefunded, "Funds already finalized");
        require(msg.sender == agreement.seller || msg.sender == agreement.arbiter, "Not authorized");

        agreement.isRefunded = true;
        emit FundsRefunded(_escrowId, msg.sender);

        (bool success, ) = agreement.buyer.call{value: agreement.amount}("");
        require(success, "Refund failed");
    }

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

    /// 🔹 New: Returns escrow IDs associated with the caller
    function getMyEscrows() external view returns (uint256[] memory) {
        return userEscrows[msg.sender];
    }

    /// 🔹 New: Get escrow count by role
    function getEscrowsByRole(address _user, string memory role) external view returns (uint256[] memory) {
        uint256[] memory all = userEscrows[_user];
        uint256 count = 0;

        for (uint256 i = 0; i < all.length; i++) {
            EscrowAgreement storage agreement = agreements[all[i]];
            if (
                (keccak256(bytes(role)) == keccak256("buyer") && agreement.buyer == _user) ||
                (keccak256(bytes(role)) == keccak256("seller") && agreement.seller == _user) ||
                (keccak256(bytes(role)) == keccak256("arbiter") && agreement.arbiter == _user)
            ) {
                count++;
            }
        }

        uint256[] memory filtered = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < all.length; i++) {
            EscrowAgreement storage agreement = agreements[all[i]];
            if (
                (keccak256(bytes(role)) == keccak256("buyer") && agreement.buyer == _user) ||
                (keccak256(bytes(role)) == keccak256("seller") && agreement.seller == _user) ||
                (keccak256(bytes(role)) == keccak256("arbiter") && agreement.arbiter == _user)
            ) {
                filtered[index++] = all[i];
            }
        }

        return filtered;
    }

    /// 🔹 New: Allows buyer to cancel escrow before funding (not applicable if already funded)
    function cancelEscrowBeforeFunding(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.buyer == msg.sender, "Only buyer can cancel");
        require(agreement.amount == 0, "Already funded, can't
