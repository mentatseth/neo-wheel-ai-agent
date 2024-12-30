// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ILockerFactory {
    function deploy(
        address token,
        address beneficiary,
        address damnsterFactory,
        uint256 tokenId
    ) external payable returns (address);
}

interface ILocker {
    function initializer(uint256 tokenId) external;

    function collectFees(address _recipient, uint256 _tokenId) external returns (uint256, uint256);
}
