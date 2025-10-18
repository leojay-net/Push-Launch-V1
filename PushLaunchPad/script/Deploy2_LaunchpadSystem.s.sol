// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Launchpad} from "../src/launchpad/Launchpad.sol";
import {SimpleBondingCurve} from "../src/launchpad/BondingCurves/SimpleBondingCurve.sol";
import {LaunchpadLPVault} from "../src/launchpad/LaunchpadLPVault.sol";
import {Distributor} from "../src/launchpad/Distributor.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";

/**
 * @title Deploy2_LaunchpadSystem
 * @notice Deploys the Launchpad system with CREATE2 for circular dependency resolution
 * @dev Step 2 of the deployment sequence
 *
 * This script handles the circular dependency between Launchpad and BondingCurve:
 * 1. Deploys supporting contracts (Distributor, LP Vault)
 * 2. Deploys Launchpad implementation
 * 3. Predicts Launchpad proxy address using CREATE2
 * 4. Deploys BondingCurve with predicted address
 * 5. Deploys Launchpad proxy at predicted address
 * 6. Initializes Launchpad
 */
contract Deploy2_LaunchpadSystem is Script {
    // Store addresses as contract state to avoid stack too deep
    address public distributor;
    address public lpVault;
    address public launchpadImpl;
    address public bondingCurve;
    address public launchpadProxy;

    function run() public {
        // Load configuration
        address router = vm.envAddress("ROUTER_ADDRESS");
        address quoteAsset = vm.envOr(
            "QUOTE_ASSET",
            vm.envAddress("WETH9_ADDRESS")
        );
        address deployer = vm.envOr("DEPLOYER", msg.sender);
        address launchpadOwner = vm.envOr("LAUNCHPAD_OWNER", deployer);

        // Bonding curve parameters
        uint256 virtualBase = vm.envOr(
            "VIRTUAL_BASE",
            uint256(1_000_000 * 1e18)
        );
        uint256 virtualQuote = vm.envOr("VIRTUAL_QUOTE", uint256(30 ether));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        console2.log("=== Deploying Launchpad System ===");
        console2.log("Router:", router);
        console2.log("Quote Asset:", quoteAsset);
        console2.log("Launchpad Owner:", launchpadOwner);

        // Step 1: Deploy supporting contracts
        console2.log("\n--- Step 1: Deploying Supporting Contracts ---");

        console2.log("Deploying Distributor...");
        distributor = address(new Distributor());
        console2.log("Distributor:", distributor);

        console2.log("Deploying LaunchpadLPVault...");
        lpVault = address(new LaunchpadLPVault());
        console2.log("LP Vault:", lpVault);

        // Step 2: Deploy launchpad implementation
        console2.log("\n--- Step 2: Deploying Launchpad Implementation ---");
        launchpadImpl = address(new Launchpad(router, distributor));
        console2.log("Launchpad Implementation:", launchpadImpl);

        // Step 3: Predict launchpad proxy address
        console2.log("\n--- Step 3: Predicting Launchpad Proxy Address ---");
        ERC1967Factory proxyFactory = new ERC1967Factory();
        bytes32 salt = bytes32(uint256(uint160(launchpadOwner)));
        address predictedProxy = proxyFactory.predictDeterministicAddress(salt);
        console2.log("Predicted Proxy Address:", predictedProxy);

        // Step 4: Deploy bonding curve with predicted address
        console2.log("\n--- Step 4: Deploying Bonding Curve ---");
        bondingCurve = address(new SimpleBondingCurve(predictedProxy));
        console2.log("Bonding Curve:", bondingCurve);

        // Step 5: Deploy proxy at predicted address
        console2.log("\n--- Step 5: Deploying Launchpad Proxy ---");
        launchpadProxy = proxyFactory.deployDeterministicAndCall(
            launchpadImpl,
            launchpadOwner,
            salt,
            "" // Initialize separately
        );
        console2.log("Launchpad Proxy:", launchpadProxy);

        // Verify addresses match
        require(launchpadProxy == predictedProxy, "Address mismatch!");
        require(
            launchpadProxy == SimpleBondingCurve(bondingCurve).launchpad(),
            "Bonding curve launchpad mismatch!"
        );
        console2.log("[OK] Address verification passed");

        // Step 6: Initialize launchpad
        console2.log("\n--- Step 6: Initializing Launchpad ---");

        // Prepare bonding curve initialization data
        bytes memory bondingCurveInitData = abi.encodeWithSignature(
            "setVirtualReserves(uint256,uint256)",
            virtualBase,
            virtualQuote
        );

        Launchpad(launchpadProxy).initialize(
            launchpadOwner,
            quoteAsset,
            bondingCurve,
            lpVault,
            bondingCurveInitData
        );
        console2.log("[OK] Launchpad initialized");

        vm.stopBroadcast();

        // Print summary
        printSummary();
    }

    function printSummary() internal view {
        console2.log("\n=== Deployment Complete ===");
        console2.log("Distributor:", distributor);
        console2.log("LP Vault:", lpVault);
        console2.log("Bonding Curve:", bondingCurve);
        console2.log("Launchpad Implementation:", launchpadImpl);
        console2.log("Launchpad Proxy:", launchpadProxy);
        console2.log("\nSave these addresses:");
        console2.log("export DISTRIBUTOR_ADDRESS=", distributor);
        console2.log("export LP_VAULT_ADDRESS=", lpVault);
        console2.log("export BONDING_CURVE_ADDRESS=", bondingCurve);
        console2.log("export LAUNCHPAD_IMPLEMENTATION=", launchpadImpl);
        console2.log("export LAUNCHPAD_ADDRESS=", launchpadProxy);
        console2.log("\n=== All Deployments Complete ===");
        console2.log("You can now use the launchpad to create tokens!");
    }
}
