// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PushLaunchpadV2Pair} from "../src/launchpad/uniswap/PushLaunchpadV2Pair.sol";

/**
 * @title GetInitCodeHash
 * @notice Script to get the init code hash of PushLaunchpadV2Pair
 * @dev This hash is needed for CREATE2 address prediction in UniswapV2Library
 */
contract GetInitCodeHash is Script {
    function run() public view {
        bytes memory bytecode = type(PushLaunchpadV2Pair).creationCode;
        bytes32 hash = keccak256(bytecode);

        console2.log("=== PushLaunchpadV2Pair Init Code Hash ===");
        console2.log("");
        console2.logBytes32(hash);
        console2.log("");
        console2.log("Use this hash in UniswapV2Library.pairFor()");
    }
}
