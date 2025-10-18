const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Launchpad Deployment Script for Push Chain
 * 
 * Deployment Order (based on Launchpad.t.sol):
 * 1. ERC1967Factory - for proxy deployments
 * 2. SimpleBondingCurve Implementation (needs predicted launchpad address)
 * 3. LaunchpadLPVault Implementation
 * 4. Distributor
 * 5. Launchpad Implementation (needs router and distributor)
 * 6. Deploy SimpleBondingCurve Proxy
 * 7. Deploy LaunchpadLPVault Proxy
 * 8. Deploy Launchpad Proxy with initialization
 * 
 * The key insight from the tests:
 * - SimpleBondingCurve constructor requires the launchpad address (immutable)
 * - Launchpad initialize requires the bonding curve address
 * - This circular dependency is solved via CREATE2 address prediction
 */

async function main() {
    console.log("==========================================");
    console.log("Push Chain Launchpad Deployment Script");
    console.log("==========================================\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", hre.ethers.formatEther(balance), "PC\n");

    // Configuration
    const WETH_ADDRESS = process.env.WETH_ADDRESS || "0x0d0dF7E8807430A81104EA84d926139816eC7586";
    const VIRTUAL_BASE = hre.ethers.parseEther("200000000"); // 200M tokens
    const VIRTUAL_QUOTE = hre.ethers.parseEther("10"); // 10 WETH

    console.log("Configuration:");
    console.log("- WETH Address:", WETH_ADDRESS);
    console.log("- Virtual Base:", hre.ethers.formatEther(VIRTUAL_BASE));
    console.log("- Virtual Quote:", hre.ethers.formatEther(VIRTUAL_QUOTE), "\n");

    const deployedAddresses = {};

    try {
        // ========================================
        // Step 1: Deploy ERC1967Factory
        // ========================================
        console.log("Step 1: Deploying ERC1967Factory...");
        const ERC1967Factory = await hre.ethers.getContractFactory("ERC1967Factory");
        const factory = await ERC1967Factory.deploy();
        await factory.waitForDeployment();
        deployedAddresses.ERC1967Factory = await factory.getAddress();
        console.log("✅ ERC1967Factory deployed to:", deployedAddresses.ERC1967Factory, "\n");

        // ========================================
        // Step 2: Predict Launchpad Proxy Address
        // ========================================
        console.log("Step 2: Predicting Launchpad Proxy Address...");

        // Create salt with deployer address prefix (required by ERC1967Factory)
        // Salt format: [20 bytes deployer address][12 bytes arbitrary data]
        const deployerAddress = deployer.address.toLowerCase().slice(2); // Remove 0x
        const arbitraryData = "000000000000000000000000"; // 12 bytes of zeros
        const launchpadSalt = "0x" + deployerAddress + arbitraryData;

        console.log("Salt:", launchpadSalt);

        // Predict the launchpad proxy address
        const predictedLaunchpadAddress = await factory.predictDeterministicAddress(launchpadSalt);
        deployedAddresses.LaunchpadProxy = predictedLaunchpadAddress;
        console.log("✅ Predicted Launchpad Address:", predictedLaunchpadAddress, "\n");

        // ========================================
        // Step 3: Deploy Distributor (Mock for now)
        // ========================================
        console.log("Step 3: Deploying Distributor...");
        const MockDistributor = await hre.ethers.getContractFactory("MockDistributor");
        const distributor = await MockDistributor.deploy();
        await distributor.waitForDeployment();
        deployedAddresses.Distributor = await distributor.getAddress();
        console.log("✅ Distributor deployed to:", deployedAddresses.Distributor, "\n");

        // ========================================
        // Step 4: Deploy UniswapV2 Router (Mock for now)
        // ========================================
        console.log("Step 4: Deploying MockUniV2Router...");
        const MockUniV2Router = await hre.ethers.getContractFactory("MockUniV2Router");
        const router = await MockUniV2Router.deploy(deployer.address); // Pass factory address
        await router.waitForDeployment();
        deployedAddresses.UniV2Router = await router.getAddress();
        console.log("✅ MockUniV2Router deployed to:", deployedAddresses.UniV2Router, "\n");

        // ========================================
        // Step 5: Deploy SimpleBondingCurve Implementation
        // ========================================
        console.log("Step 5: Deploying SimpleBondingCurve Implementation...");
        const SimpleBondingCurve = await hre.ethers.getContractFactory("SimpleBondingCurve");
        const bondingCurveImpl = await SimpleBondingCurve.deploy(predictedLaunchpadAddress);
        await bondingCurveImpl.waitForDeployment();
        deployedAddresses.SimpleBondingCurveImpl = await bondingCurveImpl.getAddress();
        console.log("✅ SimpleBondingCurve Implementation deployed to:", deployedAddresses.SimpleBondingCurveImpl);
        console.log("   (Configured for launchpad:", predictedLaunchpadAddress, ")\n");

        // ========================================
        // Step 6: Deploy LaunchpadLPVault Implementation
        // ========================================
        console.log("Step 6: Deploying LaunchpadLPVault Implementation...");
        const LaunchpadLPVault = await hre.ethers.getContractFactory("LaunchpadLPVault");
        const lpVaultImpl = await LaunchpadLPVault.deploy();
        await lpVaultImpl.waitForDeployment();
        deployedAddresses.LaunchpadLPVaultImpl = await lpVaultImpl.getAddress();
        console.log("✅ LaunchpadLPVault Implementation deployed to:", deployedAddresses.LaunchpadLPVaultImpl, "\n");

        // ========================================
        // Step 7: Deploy Launchpad Implementation
        // ========================================
        console.log("Step 7: Deploying Launchpad Implementation...");
        const Launchpad = await hre.ethers.getContractFactory("Launchpad");
        const launchpadImpl = await Launchpad.deploy(
            deployedAddresses.UniV2Router,
            deployedAddresses.Distributor
        );
        await launchpadImpl.waitForDeployment();
        deployedAddresses.LaunchpadImpl = await launchpadImpl.getAddress();
        console.log("✅ Launchpad Implementation deployed to:", deployedAddresses.LaunchpadImpl, "\n");

        // ========================================
        // Step 8: Deploy SimpleBondingCurve Proxy
        // ========================================
        console.log("Step 8: Deploying SimpleBondingCurve Proxy...");
        const bondingCurveTx = await factory.deploy(
            deployedAddresses.SimpleBondingCurveImpl,
            deployer.address
        );
        await bondingCurveTx.wait();

        // Get the proxy address from the event
        const bondingCurveReceipt = await hre.ethers.provider.getTransactionReceipt(bondingCurveTx.hash);
        const bondingCurveProxyAddress = "0x" + bondingCurveReceipt.logs[0].topics[1].slice(26);
        deployedAddresses.SimpleBondingCurveProxy = bondingCurveProxyAddress;
        console.log("✅ SimpleBondingCurve Proxy deployed to:", deployedAddresses.SimpleBondingCurveProxy, "\n");

        // ========================================
        // Step 9: Deploy LaunchpadLPVault Proxy
        // ========================================
        console.log("Step 9: Deploying LaunchpadLPVault Proxy...");
        const lpVaultTx = await factory.deploy(
            deployedAddresses.LaunchpadLPVaultImpl,
            deployer.address
        );
        await lpVaultTx.wait();

        const lpVaultReceipt = await hre.ethers.provider.getTransactionReceipt(lpVaultTx.hash);
        const lpVaultProxyAddress = "0x" + lpVaultReceipt.logs[0].topics[1].slice(26);
        deployedAddresses.LaunchpadLPVaultProxy = lpVaultProxyAddress;
        console.log("✅ LaunchpadLPVault Proxy deployed to:", deployedAddresses.LaunchpadLPVaultProxy, "\n");

        // ========================================
        // Step 10: Deploy Launchpad Proxy with Initialization
        // ========================================
        console.log("Step 10: Deploying Launchpad Proxy with initialization...");

        // Encode initialization data
        const initData = Launchpad.interface.encodeFunctionData("initialize", [
            deployer.address, // owner
            WETH_ADDRESS, // quoteAsset
            deployedAddresses.SimpleBondingCurveProxy, // bondingCurve
            deployedAddresses.LaunchpadLPVaultProxy, // launchpadLPVault
            hre.ethers.AbiCoder.defaultAbiCoder().encode(
                ["uint256", "uint256"],
                [VIRTUAL_BASE, VIRTUAL_QUOTE]
            ) // bondingCurveInitData
        ]);

        console.log("Deploying at predicted address:", predictedLaunchpadAddress);
        const launchpadTx = await factory.deployDeterministicAndCall(
            deployedAddresses.LaunchpadImpl,
            deployer.address,
            launchpadSalt,
            initData
        );
        await launchpadTx.wait();

        console.log("✅ Launchpad Proxy deployed to:", predictedLaunchpadAddress, "\n");

        // ========================================
        // Verification
        // ========================================
        console.log("==========================================");
        console.log("Deployment Summary");
        console.log("==========================================");
        console.log("ERC1967Factory:", deployedAddresses.ERC1967Factory);
        console.log("Distributor:", deployedAddresses.Distributor);
        console.log("UniV2Router (Mock):", deployedAddresses.UniV2Router);
        console.log("\nImplementations:");
        console.log("- SimpleBondingCurve:", deployedAddresses.SimpleBondingCurveImpl);
        console.log("- LaunchpadLPVault:", deployedAddresses.LaunchpadLPVaultImpl);
        console.log("- Launchpad:", deployedAddresses.LaunchpadImpl);
        console.log("\nProxies (Main Contracts):");
        console.log("- SimpleBondingCurve:", deployedAddresses.SimpleBondingCurveProxy);
        console.log("- LaunchpadLPVault:", deployedAddresses.LaunchpadLPVaultProxy);
        console.log("- Launchpad:", deployedAddresses.LaunchpadProxy);
        console.log("==========================================\n");

        // Save deployment addresses to file
        const deploymentsDir = path.join(__dirname, "..", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir);
        }

        const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
        const filename = path.join(deploymentsDir, `push_testnet_${timestamp}.json`);

        fs.writeFileSync(
            filename,
            JSON.stringify(deployedAddresses, null, 2)
        );
        console.log("✅ Deployment addresses saved to:", filename, "\n");

        console.log("==========================================");
        console.log("Next Steps:");
        console.log("==========================================");
        console.log("1. Verify contracts on block explorer:");
        console.log("   npx hardhat verify --network push_testnet <address>");
        console.log("\n2. Test the launchpad by launching a token");
        console.log("\n3. Update Factory with launchpad addresses if using real Factory contract");
        console.log("==========================================\n");

    } catch (error) {
        console.error("\n❌ Deployment failed:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
