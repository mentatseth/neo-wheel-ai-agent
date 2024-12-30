// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IDpadStaking} from "./interfaces/IDpadStaking.sol";
import {AddressStorage} from "./AddressStorage.sol";

abstract contract HoldingList is OwnableUpgradeable, AddressStorage {
    mapping(address => uint256) public holdingAmounts;

    function __HoldingList__init(address owner_) internal onlyInitializing {
        ///@dev there's no holding limitation
        holdingAmounts[DEGEN] = type(uint256).max;
        holdingAmounts[DPAD] = type(uint256).max;

        __Ownable_init(owner_);
    }

    function isHolder(address target) public view returns (bool) {
        return (
            (holdingAmounts[DEGEN] == type(uint256).max && holdingAmounts[DPAD] == type(uint256).max) ||
            _balanceOf(DEGEN, target) >= holdingAmounts[DEGEN] || 
            _balanceOf(DPAD, target) >= holdingAmounts[DPAD]
        );
    }

    function updateHoldingAmounts(address token, uint256 amounts) public onlyOwner {
        holdingAmounts[token] = amounts == 0 ? type(uint256).max : amounts;
    }

    function _balanceOf(address token, address user) private view returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(user);
        if(token == address(DPAD)) {
            IDpadStaking dpadStaking = IDpadStaking(DPAD_STAKING);
            uint256 staking = (dpadStaking.userStakes(dpadStaking.lastSeasonId(), user)).amount;
            return balance + staking;
        }
        else if(token == address(DEGEN)) {
            return balance + IERC20(LDEGEN).balanceOf(user);
        }

        return balance;
    }
}