/// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.11;

interface IYVault {
    function deposit(uint256) external;

    function withdraw(uint256) external;

    function getPricePerFullShare() external view returns (uint256);

    function token() external view returns (address);

    // V2
    function pricePerShare() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);
}