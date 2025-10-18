// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PushLaunchpadV2PairFactory} from "../src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol";
import {PushLaunchpadV2Router2} from "../src/launchpad/uniswap/PushLaunchpadV2Router2.sol";

/**
 * @title Deploy1_UniswapV2
 * @notice Deploys Uniswap V2 Core and Periphery contracts
 * @dev Step 1 of the deployment sequence
 */
contract Deploy1_UniswapV2 is Script {
    function run() public {
        // Load configuration
        address deployer = vm.envOr("DEPLOYER", msg.sender);
        address feeToSetter = vm.envOr("FEE_TO_SETTER", deployer);
        address weth = vm.envAddress("WETH9_ADDRESS");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        console2.log("=== Deploying Uniswap V2 System ===");
        console2.log("Deployer:", deployer);
        console2.log("WETH:", weth);
        console2.log("Fee To Setter:", feeToSetter);

        // Deploy Factory with zero addresses for launchpad (will be set later)
        console2.log("\nDeploying PushLaunchpadV2PairFactory...");
        address factory = address(
            new PushLaunchpadV2PairFactory(
                feeToSetter,
                address(0), // launchpad - to be set after launchpad deployment
                address(0), // launchpadLp - to be set after lpVault deployment
                address(0) // launchpadFeeDistributor - to be set after distributor deployment
            )
        );
        console2.log("Factory deployed at:", factory);

        // Deploy Router
        console2.log("\nDeploying PushLaunchpadV2Router2...");
        address router = address(new PushLaunchpadV2Router2(factory, weth));
        console2.log("Router deployed at:", router);

        vm.stopBroadcast();

        // Print summary
        console2.log("\n=== Deployment Complete ===");
        console2.log("Save these addresses:");
        console2.log("export FACTORY_ADDRESS=", factory);
        console2.log("export ROUTER_ADDRESS=", router);
        console2.log("\nNext: Run Deploy2_LaunchpadSystem.s.sol");
    }
}
