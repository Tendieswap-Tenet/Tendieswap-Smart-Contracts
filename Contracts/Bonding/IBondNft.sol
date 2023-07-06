// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBondNft {
    struct Bond {
        uint256 payout; 
        uint256 payoutClaimed;
        uint256 vestingTerm; 
        uint256 vestingStartTimestamp;
        uint256 lastClaimTimestamp; 
        uint256 truePricePaid; 
    }

    function mintBond( address _recipient, Bond memory _bond) external returns (uint256 bondId);

    function getTokenData(uint256 tokenId) external view returns (Bond memory);
}
