// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { LpLocker } from "./LpLocker.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LockerFactory is OwnableUpgradeable {
    event deployed(
        address indexed lockerAddress,
        address indexed owner,
        uint256 tokenId,
        uint256 lockingPeriod
    );

    address public feeRecipient;
    uint8 public protocolFee;
    uint64 public defaultLockingPeriod; 

    function initialize(address _feeRecipient, address _owner) external initializer {
        feeRecipient = _feeRecipient;
        protocolFee = 60;  // denom is 100
        defaultLockingPeriod = 33291961200; // Fri Dec 24 3024 15:00:00 GMT+0000
        __Ownable_init(_owner);
    }

    function deploy(
        address token,
        address beneficiary,
        address damnsterFactory,
        uint256 tokenId
    ) public payable returns (address) {
        address newLockerAddress = address(
            new LpLocker(
                token,
                damnsterFactory,
                beneficiary,
                defaultLockingPeriod,
                protocolFee,
                feeRecipient
            )
        );

        if (newLockerAddress == address(0)) {
            revert("Invalid address");
        }

        emit deployed(newLockerAddress, beneficiary, tokenId, defaultLockingPeriod);

        return newLockerAddress;
    }

    function updateFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function updateDefaultLockingPeriod(uint64 newPeriod) external onlyOwner {
        defaultLockingPeriod = newPeriod;
    }

    function updateProtocolFees(uint8 newFee) external onlyOwner {
        protocolFee = newFee;
    }
}
