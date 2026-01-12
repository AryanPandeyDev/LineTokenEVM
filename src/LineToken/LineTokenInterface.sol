//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

interface ILineToken {
    // ERC20 Standard
    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    // Minting
    function mint(address to, uint256 amount) external;

    // Role Management
    function addMinter(address minter) external;

    function removeMinter(address minter) external;

    function isMinter(address account) external view returns (bool);

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
