// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {MockERC20} from "./MockERC20.sol";

/// @title Mintable ERC20 (Test Only)
/// @notice Extends MockERC20 with a public mint() for testing.
contract MintableERC20 is MockERC20 {
    /// @notice Public mint for testing
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
