// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

// Uniswap V2 Core
import {PushLaunchpadV2PairFactory} from "../src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol";

// Uniswap V2 Periphery - Note: These are 0.8.27 now
import {PushLaunchpadV2Router2} from "../src/launchpad/uniswap/PushLaunchpadV2Router2.sol";

// Launchpad System
import {Launchpad} from "../src/launchpad/Launchpad.sol";
import {SimpleBondingCurve} from "../src/launchpad/BondingCurves/SimpleBondingCurve.sol";
import {LaunchpadLPVault} from "../src/launchpad/LaunchpadLPVault.sol";
import {Distributor} from "../src/launchpad/Distributor.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";

/**
 * @title DeployAll
 * @notice Comprehensive deployment script for the entire Push Launchpad system
 * @dev Deployment Order:
 *      1. Deploy Uniswap V2 Core (Factory)
 *      2. Deploy Uniswap V2 Periphery (Router)
 *      3. Deploy Launchpad Supporting Contracts (Distributor, LP Vault)
 *      4. Deploy Bonding Curve
 *      5. Deploy Launchpad Implementation + Proxy
 *      6. Initialize Launchpad
 */
contract DeployAll is Script {
    // Deployment addresses
    address public factory;
    address public router;
    address public distributor;
    address public lpVault;
    address public bondingCurve;
    address public launchpadImpl;
    address public launchpadProxy;

    // Configuration
    address public weth;
    address public quoteAsset; // The token used for trading (e.g., WETH or stablecoin)
    address public deployer;
    address public launchpadOwner;
    address public feeToSetter;

    // Bonding curve parameters
    uint256 public virtualBase = 1_000_000 * 1e18; // 1M tokens
    uint256 public virtualQuote = 30 ether; // 30 ETH
    uint256 public graduationThreshold = 24_000 ether; // 24k quote tokens to graduate

    function setUp() public {
        // Load from environment or use defaults
        deployer = vm.envOr("DEPLOYER", msg.sender);
        launchpadOwner = vm.envOr("LAUNCHPAD_OWNER", deployer);
        feeToSetter = vm.envOr("FEE_TO_SETTER", deployer);
        weth = vm.envOr("WETH9_ADDRESS", address(0));
        quoteAsset = vm.envOr("QUOTE_ASSET", weth);

        // Load bonding curve params if provided
        virtualBase = vm.envOr("VIRTUAL_BASE", virtualBase);
        virtualQuote = vm.envOr("VIRTUAL_QUOTE", virtualQuote);
        graduationThreshold = vm.envOr(
            "GRADUATION_THRESHOLD",
            graduationThreshold
        );
    }

    function run() public {
        require(weth != address(0), "WETH address not set");
        require(quoteAsset != address(0), "Quote asset not set");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        console2.log("=== Starting Full Push Launchpad Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("WETH:", weth);
        console2.log("Quote Asset:", quoteAsset);

        // Step 1: Deploy Uniswap V2 Core (Factory)
        console2.log("\n--- Step 1: Deploying Uniswap V2 Factory ---");
        deployFactory();

        // Step 2: Deploy Uniswap V2 Periphery (Router)
        console2.log("\n--- Step 2: Deploying Uniswap V2 Router ---");
        deployRouter();

        // Step 3: Deploy Launchpad Supporting Contracts
        console2.log("\n--- Step 3: Deploying Supporting Contracts ---");
        deploySupportingContracts();

        // Step 4: Deploy Bonding Curve
        console2.log("\n--- Step 4: Deploying Bonding Curve ---");
        deployBondingCurve();

        // Step 5: Deploy Launchpad
        console2.log("\n--- Step 5: Deploying Launchpad ---");
        deployLaunchpad();

        // Step 6: Initialize Launchpad
        console2.log("\n--- Step 6: Initializing Launchpad ---");
        initializeLaunchpad();

        vm.stopBroadcast();

        // Print deployment summary
        printDeploymentSummary();
    }

    function deployFactory() internal {
        console2.log("Deploying PushLaunchpadV2PairFactory...");

        // We need to predict the launchpad proxy address for the factory constructor
        // For now, we'll use address(0) and update it later, or deploy in different order
        // Alternative: Pass these as zero addresses and set them later
        factory = address(
            new PushLaunchpadV2PairFactory(
                feeToSetter,
                address(0), // launchpad - will be set after launchpad deployment
                address(0), // launchpadLp - will be set after lpVault deployment
                address(0) // launchpadFeeDistributor - will be set after distributor deployment
            )
        );

        console2.log("Factory deployed at:", factory);
    }

    function deployRouter() internal {
        console2.log("Deploying PushLaunchpadV2Router2...");

        router = address(new PushLaunchpadV2Router2(factory, weth));

        console2.log("Router deployed at:", router);
    }

    function deploySupportingContracts() internal {
        // Deploy Distributor
        console2.log("Deploying Distributor...");
        distributor = address(new Distributor());
        console2.log("Distributor deployed at:", distributor);

        // Deploy LP Vault
        console2.log("Deploying LaunchpadLPVault...");
        lpVault = address(new LaunchpadLPVault());
        console2.log("LP Vault deployed at:", lpVault);
    }

    function deployBondingCurve() internal {
        console2.log("Deploying SimpleBondingCurve...");

        // Deploy proxy factory
        ERC1967Factory proxyFactory = new ERC1967Factory();

        // Deploy launchpad implementation
        Launchpad launchpadImplementation = new Launchpad(router, distributor);
        launchpadImpl = address(launchpadImplementation);

        // Predict launchpad proxy address using salt
        bytes32 salt = bytes32(uint256(uint160(launchpadOwner)));
        address predictedLaunchpad = proxyFactory.predictDeterministicAddress(
            salt
        );

        console2.log("Predicted Launchpad Proxy:", predictedLaunchpad);

        // Deploy bonding curve with predicted launchpad address
        bondingCurve = address(new SimpleBondingCurve(predictedLaunchpad));
        console2.log("Bonding Curve deployed at:", bondingCurve);
    }

    function deployLaunchpad() internal {
        console2.log("Deploying Launchpad Proxy...");

        // Deploy proxy factory if not already deployed
        ERC1967Factory proxyFactory = new ERC1967Factory();

        // Deploy proxy using CREATE2 for deterministic address
        bytes32 salt = bytes32(uint256(uint160(launchpadOwner)));
        launchpadProxy = proxyFactory.deployDeterministicAndCall(
            launchpadImpl,
            launchpadOwner,
            salt,
            "" // We'll initialize separately
        );

        console2.log("Launchpad Proxy deployed at:", launchpadProxy);

        // Verify the address matches our prediction
        require(
            launchpadProxy == SimpleBondingCurve(bondingCurve).launchpad(),
            "Address mismatch!"
        );
    }

    function initializeLaunchpad() internal {
        console2.log("Initializing Launchpad...");

        // Prepare bonding curve setup data (if needed)
        bytes memory bondingCurveSetupData = abi.encodeWithSignature(
            "setVirtualReserves(uint256,uint256)",
            virtualBase,
            virtualQuote
        );

        // Initialize the launchpad with correct parameters
        Launchpad(launchpadProxy).initialize(
            launchpadOwner,
            quoteAsset,
            bondingCurve,
            lpVault,
            bondingCurveSetupData
        );

        console2.log("Launchpad initialized successfully");

        // Note: If factory needs updating with launchpad addresses, do it here
        // This would require setter functions in PushLaunchpadV2PairFactory
        // Or the factory should be deployed AFTER the launchpad system
    }

    function printDeploymentSummary() internal view {
        console2.log("\n=== Deployment Summary ===");
        console2.log("Factory:", factory);
        console2.log("Router:", router);
        console2.log("Distributor:", distributor);
        console2.log("LP Vault:", lpVault);
        console2.log("Bonding Curve:", bondingCurve);
        console2.log("Launchpad Implementation:", launchpadImpl);
        console2.log("Launchpad Proxy:", launchpadProxy);
        console2.log("\n=== Configuration ===");
        console2.log("WETH:", weth);
        console2.log("Quote Asset:", quoteAsset);
        console2.log("Virtual Base:", virtualBase);
        console2.log("Virtual Quote:", virtualQuote);
        console2.log("Graduation Threshold:", graduationThreshold);
        console2.log("\n=== SAVE THESE ADDRESSES ===");
        console2.log("export FACTORY_ADDRESS=", factory);
        console2.log("export ROUTER_ADDRESS=", router);
        console2.log("export LAUNCHPAD_ADDRESS=", launchpadProxy);
        console2.log("export BONDING_CURVE_ADDRESS=", bondingCurve);
    }
}
