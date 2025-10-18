// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../univ2-core/interfaces/IERC20.sol";

interface IWETHLike is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

/// @title Mintable WETH (Test Only)
/// @notice Simple WETH-like token with public mint() for testing deployments.
contract MintableWETH is IWETHLike {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // --- ERC20 ---
    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "ERC20: insufficient allowance");
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "ERC20: transfer to zero");
        uint256 bal = balanceOf[from];
        require(bal >= value, "ERC20: transfer exceeds balance");
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }

    // --- WETH behavior ---
    function deposit() public payable override {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external override {
        uint256 bal = balanceOf[msg.sender];
        require(bal >= wad, "WETH: insufficient");
        unchecked {
            balanceOf[msg.sender] = bal - wad;
            totalSupply -= wad;
        }
        (bool ok, ) = msg.sender.call{value: wad}("");
        require(ok, "WETH: ETH transfer failed");
        emit Withdrawal(msg.sender, wad);
        emit Transfer(msg.sender, address(0), wad);
    }

    // --- Test helper ---
    /// @notice Mint arbitrary amount to any account. TEST ONLY.
    function mint(address to, uint256 amount) external {
        require(to != address(0), "mint to zero");
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    receive() external payable {
        deposit();
    }
}
