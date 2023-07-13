// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

interface IBondDeposit {
    struct BondTerms {
        uint256 controlVariable;
        uint256 vestingTerm;
        uint256 minimumPrice;
        uint256 maxPayout;
        uint256 maxDebt;
        uint256 maxTotalPayout;
    }

    function payoutToken() external view returns (address);
    function principalToken() external view returns (address);
    function DAO() external view returns (address);
    function bondNft() external view returns (address);
    function vestingCurve() external view returns (address);
    function totalPrincipalBonded() external view returns (uint256);
    function totalPayoutGiven() external view returns (uint256);
    function terms() external view returns (BondTerms memory);
    function totalDebt() external view returns (uint256);
    function lastDecay() external view returns (uint256);
    function getMaxTotalPayout() external view returns (uint256);

    function getBondTerms() external view returns (
        uint256 controlVariable,
        uint256 vestingTerm,
        uint256 minimumPrice,
        uint256 maxPayout,
        uint256 maxDebt,
        uint256 maxTotalPayout
    );

    function calculatePayout(uint256 amount) external view returns (uint256);
}