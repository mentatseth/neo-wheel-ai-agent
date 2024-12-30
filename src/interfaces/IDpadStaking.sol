// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDpadStaking {
    struct StakeInfo {
        uint256 amount;
        uint256 currentPointStored;
        uint256 expectedPointStored;
        uint256 lastUpdateTime;
    }

    function lastSeasonId() external view returns (uint256);

    function userStakes(uint256, address) external view returns (StakeInfo memory); 
}