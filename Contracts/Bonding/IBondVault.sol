pragma solidity ^0.8.0;

interface IBondVault {
    function bondPayoutAmount(address _depositor) external view returns (uint payoutTotal);

    function bondPayoutAmountDivSupply(address _depositor) external view returns (uint payoutSupplyPercent);

    function bondPayoutAmountDivBondedSupply(address _depositor) external view returns (uint payoutBondedPercent);
} 