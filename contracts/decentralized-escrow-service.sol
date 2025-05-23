mapping(address => uint256[]) private sellerRatings;
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
