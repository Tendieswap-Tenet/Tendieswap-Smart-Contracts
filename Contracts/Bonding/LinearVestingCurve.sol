// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "Bonding/IVestingCurve.sol";

contract LinearVestingCurve is IVestingCurve {
    /**
     * @dev See {IVestingCurve-getVestedPayoutAtTime}.
     */
    function getVestedPayoutAtTime(
        uint256 totalPayout,
        uint256 vestingTerm,
        uint256 startTimestamp,
        uint256 checkTimestamp
    ) external pure returns (uint256 vestedPayout) {
        if (checkTimestamp <= startTimestamp) {
            vestedPayout = 0;
        } else if (checkTimestamp >= (startTimestamp + vestingTerm)) {
            vestedPayout = totalPayout;
        } else {
            /// @dev This is where custom vesting curves can be implemented.
            vestedPayout = (totalPayout * (checkTimestamp - startTimestamp)) / vestingTerm;
        }
    }
}