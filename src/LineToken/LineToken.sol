// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ILineToken} from "./LineTokenInterface.sol";

contract LineToken is ILineToken {
    //errors
    error CallerNotMinter(address caller);
    error NotEnoughBalance(address account, uint256 amount);
    error CallerNotSpender(address caller);
    error InsufficientApproval(
        address spender,
        uint256 approvedAmount,
        uint256 triedAmount
    );
    error InsufficeintBalance(
        address owner,
        uint256 balance,
        uint256 triedAmount
    );
    error CallerNotOwner(address caller);

    //state variables
    address immutable iOwner;
    mapping(address => bool) private s_isMinter;
    mapping(address => uint256 amount) private s_balanceOfAddresses;
    mapping(address => mapping(address => uint256)) private s_ownerToSpender;
    string constant TOKEN_NAME = "Line token";
    string constant TOKEN_SYMBOL = "LINE";
    uint256 constant DECIMALS = 18;
    uint256 private s_totalSupply;

    constructor() {
        iOwner = msg.sender;
        s_isMinter[msg.sender] = true;
    }

    modifier onlyOwner() {
        if (msg.sender != iOwner) revert CallerNotOwner(msg.sender);
        _;
    }

    function mint(address toAddress, uint256 amount) external {
        if (!isMinter(msg.sender)) revert CallerNotMinter(msg.sender);
        s_balanceOfAddresses[toAddress] += amount;
        s_totalSupply += amount;
        emit Transfer(address(0), toAddress, amount);
    }

    function name() external pure override returns (string memory) {
        return TOKEN_NAME;
    }

    function symbol() external pure override returns (string memory) {
        return TOKEN_SYMBOL;
    }

    function decimals() external pure override returns (uint8) {
        return uint8(DECIMALS);
    }

    function totalSupply() external view override returns (uint256) {
        return s_totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return s_balanceOfAddresses[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        uint256 balance = balanceOf(address(msg.sender));
        if (balance < amount)
            revert InsufficeintBalance(msg.sender, balance, amount);
        s_balanceOfAddresses[msg.sender] -= amount;
        s_balanceOfAddresses[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address _spender, uint256 amount) external returns (bool) {
        s_ownerToSpender[msg.sender][_spender] = amount;
        emit Approval(msg.sender, _spender, amount);
        return true;
    }

    function allowance(
        address owner,
        address _spender
    ) external view override returns (uint256) {
        return s_ownerToSpender[owner][_spender];
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 amountApproved = s_ownerToSpender[from][msg.sender];
        uint256 balance = balanceOf(address(from));
        if (amountApproved == 0) revert CallerNotSpender(msg.sender);
        if (amountApproved < amount)
            revert InsufficientApproval(msg.sender, amountApproved, amount);
        if (balance < amount)
            revert InsufficeintBalance(msg.sender, balance, amount);
        s_balanceOfAddresses[from] -= amount;
        s_balanceOfAddresses[to] += amount;
        s_ownerToSpender[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function addMinter(address minter) external override onlyOwner {
        s_isMinter[minter] = true;
    }

    function removeMinter(address minter) external override onlyOwner {
        delete s_isMinter[minter];
    }

    function isMinter(address account) public view override returns (bool) {
        return s_isMinter[account];
    }

    function getOwner() public view returns (address) {
        return iOwner;
    }
}
