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

    mapping(address => uint256[]) private userEscrows;

    event EscrowCreated(uint256 escrowId, address buyer, address seller, address arbiter, uint256 amount, string description);
    event FundsReleased(uint256 escrowId, address releasedBy);
    event FundsRefunded(uint256 escrowId, address refundedBy);
    event EscrowCancelled(uint256 escrowId, address cancelledBy);
    event EscrowFunded(uint256 escrowId, uint256 amount);
    event ArbiterUpdated(uint256 escrowId, address oldArbiter, address newArbiter); // 🔹 New

    function createEscrow(address _seller, address _arbiter, string memory _description) external payable returns (uint256) {
        require(_seller != address(0), "Invalid seller address");
        require(_arbiter != address(0), "Invalid arbiter address");

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

        userEscrows[msg.sender].push(escrowId);
        userEscrows[_seller].push(escrowId);
        userEscrows[_arbiter].push(escrowId);

        nextEscrowId++;

        emit EscrowCreated(escrowId, msg.sender, _seller, _arbiter, msg.value, _description);
        return escrowId;
    }

    function fundEscrow(uint256 _escrowId) external payable {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.buyer == msg.sender, "Only buyer can fund");
        require(!agreement.isReleased && !agreement.isRefunded, "Escrow finalized");

        agreement.amount += msg.value;
        emit EscrowFunded(_escrowId, msg.value);
    }

    function releaseFunds(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.amount > 0, "Escrow not funded");
        require(!agreement.isReleased && !agreement.isRefunded, "Funds already finalized");
        require(msg.sender == agreement.buyer || msg.sender == agreement.arbiter, "Not authorized");

        agreement.isReleased = true;
        emit FundsReleased(_escrowId, msg.sender);

        (bool success, ) = agreement.seller.call{value: agreement.amount}("");
        require(success, "Transfer failed");
    }

    function refundBuyer(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.amount > 0, "Escrow not funded");
        require(!agreement.isReleased && !agreement.isRefunded, "Funds already finalized");
        require(msg.sender == agreement.seller || msg.sender == agreement.arbiter, "Not authorized");

        agreement.isRefunded = true;
        emit FundsRefunded(_escrowId, msg.sender);

        (bool success, ) = agreement.buyer.call{value: agreement.amount}("");
        require(success, "Refund failed");
    }

    function cancelEscrowBeforeFunding(uint256 _escrowId) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(agreement.buyer == msg.sender, "Only buyer can cancel");
        require(agreement.amount == 0, "Already funded");

        delete agreements[_escrowId];
        emit EscrowCancelled(_escrowId, msg.sender);
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

    function getMyEscrows() external view returns (uint256[] memory) {
        return userEscrows[msg.sender];
    }

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

    // 🔹 New: Check if escrow is still active
    function isEscrowActive(uint256 _escrowId) public view returns (bool) {
        EscrowAgreement storage agreement = agreements[_escrowId];
        return !(agreement.isReleased || agreement.isRefunded);
    }

    // 🔹 New: Get user’s escrow count
    function getEscrowCount(address user) external view returns (uint256) {
        return userEscrows[user].length;
    }

    // 🔹 New: Get active escrows only
    function getActiveEscrows(address user) external view returns (uint256[] memory) {
        uint256[] memory all = userEscrows[user];
        uint256 count = 0;

        for (uint256 i = 0; i < all.length; i++) {
            if (isEscrowActive(all[i])) {
                count++;
            }
        }

        uint256[] memory active = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < all.length; i++) {
            if (isEscrowActive(all[i])) {
                active[index++] = all[i];
            }
        }

        return active;
    }

    // 🔹 New: Buyer can update arbiter before funds are finalized
    function updateArbiter(uint256 _escrowId, address newArbiter) external {
        EscrowAgreement storage agreement = agreements[_escrowId];
        require(msg.sender == agreement.buyer, "Only buyer can update");
        require(!agreement.isReleased && !agreement.isRefunded, "Escrow finalized");
        require(newArbiter != address(0), "Invalid address");

        address oldArbiter = agreement.arbiter;
        agreement.arbiter = newArbiter;

        userEscrows[newArbiter].push(_escrowId);
        emit ArbiterUpdated(_escrowId, oldArbiter, newArbiter);
    }

    // 🔹 New: Admin view - get all escrow IDs
    function getAllEscrows() external view returns (uint256[] memory) {
        uint256[] memory all = new uint256[](nextEscrowId);
        for (uint256 i = 0; i < nextEscrowId; i++) {
            all[i] = i;
        }
        return all;
    }
}mapping(address => uint256[]) private sellerRatings;
mapping(address => uint256[]) private arbiterRatings;

event SellerRated(address indexed seller, uint8 rating, uint256 escrowId);
event ArbiterRated(address indexed arbiter, uint8 rating, uint256 escrowId);

function rateParticipants(uint256 _escrowId, uint8 sellerRating, uint8 arbiterRating) external {
    EscrowAgreement storage agreement = agreements[_escrowId];
    require(agreement.buyer == msg.sender, "Only buyer can rate");
    require(agreement.isReleased || agreement.isRefunded, "Escrow not completed");
    require(sellerRating >= 1 && sellerRating <= 5, "Invalid seller rating");
    require(arbiterRating >= 1 && arbiterRating <= 5, "Invalid arbiter rating");

    sellerRatings[agreement.seller].push(sellerRating);
    arbiterRatings[agreement.arbiter].push(arbiterRating);

    emit SellerRated(agreement.seller, sellerRating, _escrowId);
    emit ArbiterRated(agreement.arbiter, arbiterRating, _escrowId);
}

function getAverageRating(address user, string memory role) external view returns (uint256) {
    uint256[] storage ratings = keccak256(bytes(role)) == keccak256("seller") ? sellerRatings[user] : arbiterRatings[user];
    if (ratings.length == 0) return 0;

    uint256 sum = 0;
    for (uint256 i = 0; i < ratings.length; i++) {
        sum += ratings[i];
    }
    return sum / ratings.length;
}
