pragma solidity ^0.8.0;

interface ITendies {
    
    function mintRewards(uint256 rewardIndex, uint256 amount, address recipient) external;
    function mintTeam(uint256 teamIndex, uint256 amount, address recipient) external;

    function emissions(uint256 index) external view returns (uint256);
    function emissionsCap(uint256 index) external view returns (uint256);
}