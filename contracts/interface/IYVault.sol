/// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.11;

interface IYVault {
    function deposit(uint256) external returns (uint256);

    function withdraw(uint256) external returns (uint256);

    function withdraw(uint256, address) external returns (uint256);

    function token() external view returns (address);

    function pricePerShare() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
