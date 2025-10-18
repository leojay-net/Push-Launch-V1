const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Production Launchpad Deployment Script for Push Chain
 * Uses already deployed Router and Factory contracts
 * 
 * Prerequisites:
 * - Router2 already deployed
 * - Factory already deployed  
 * - WETH already deployed
 */

async function main() {
    console.log("==========================================");
    console.log("Push Chain Launchpad Production Deployment");
    console.log("==========================================\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", hre.ethers.formatEther(balance), "PC\n");

    // ========================================
    // Configuration - ALREADY DEPLOYED CONTRACTS
    // ========================================
    const config = {
        WETH_ADDRESS: "0x0d0dF7E8807430A81104EA84d926139816eC7586",
        ROUTER_ADDRESS: "0x4Ca62344a28EB039F4c648834c0118Dd5CD8CDDA", // Router2
        FACTORY_ADDRESS: "0xc1E90F13067f8cC3B1917E312A988496F875d924", // Factory
        ERC1967_FACTORY: "0x902158dD97A2D82D89f68c61D307fD7dD2e264ed",
        VIRTUAL_BASE: hre.ethers.parseEther("200000000"), // 200M tokens
        VIRTUAL_QUOTE: hre.ethers.parseEther("10"), // 10 WETH
    };

    console.log("Using deployed contracts:");
    console.log("- WETH:", config.WETH_ADDRESS);
    console.log("- Router2:", config.ROUTER_ADDRESS);
    console.log("- Factory:", config.FACTORY_ADDRESS);
    console.log("- ERC1967Factory:", config.ERC1967_FACTORY, "\n");

    const deployedAddresses = { ...config };

    try {
        // Get factory instance
        const factory = await hre.ethers.getContractAt("ERC1967Factory", config.ERC1967_FACTORY);

        // ========================================
        // Step 1: Predict Launchpad Proxy Address
        // ========================================
        console.log("Step 1: Predicting Launchpad Proxy Address...");

        const deployerAddress = deployer.address.toLowerCase().slice(2);
        const arbitraryData = "000000000000000000000000";
        const launchpadSalt = "0x" + deployerAddress + arbitraryData;

        console.log("Salt:", launchpadSalt);

        const predictedLaunchpadAddress = await factory.predictDeterministicAddress(launchpadSalt);
        deployedAddresses.LaunchpadProxy = predictedLaunchpadAddress;
        console.log("✅ Predicted Launchpad Address:", predictedLaunchpadAddress, "\n");

        // ========================================
        // Step 2: Deploy Distributor
        // ========================================
        console.log("Step 2: Deploying Distributor...");
        const Distributor = await hre.ethers.getContractFactory("Distributor");
        const distributor = await Distributor.deploy();
        await distributor.waitForDeployment();
        deployedAddresses.Distributor = await distributor.getAddress();
        console.log("✅ Distributor deployed to:", deployedAddresses.Distributor, "\n");

        // ========================================
        // Step 3: Deploy SimpleBondingCurve Implementation
        // ========================================
        console.log("Step 3: Deploying SimpleBondingCurve Implementation...");
        const SimpleBondingCurve = await hre.ethers.getContractFactory("SimpleBondingCurve");
        const bondingCurveImpl = await SimpleBondingCurve.deploy(predictedLaunchpadAddress);
        await bondingCurveImpl.waitForDeployment();
        deployedAddresses.SimpleBondingCurveImpl = await bondingCurveImpl.getAddress();
        console.log("✅ SimpleBondingCurve Implementation:", deployedAddresses.SimpleBondingCurveImpl, "\n");

        // ========================================
        // Step 4: Deploy LaunchpadLPVault Implementation
        // ========================================
        console.log("Step 4: Deploying LaunchpadLPVault Implementation...");
        const LaunchpadLPVault = await hre.ethers.getContractFactory("LaunchpadLPVault");
        const lpVaultImpl = await LaunchpadLPVault.deploy();
        await lpVaultImpl.waitForDeployment();
        deployedAddresses.LaunchpadLPVaultImpl = await lpVaultImpl.getAddress();
        console.log("✅ LaunchpadLPVault Implementation:", deployedAddresses.LaunchpadLPVaultImpl, "\n");

        // ========================================
        // Step 5: Deploy Launchpad Implementation
        // ========================================
        console.log("Step 5: Deploying Launchpad Implementation...");
        const Launchpad = await hre.ethers.getContractFactory("Launchpad");
        const launchpadImpl = await Launchpad.deploy(
            config.ROUTER_ADDRESS,
            deployedAddresses.Distributor
        );
        await launchpadImpl.waitForDeployment();
        deployedAddresses.LaunchpadImpl = await launchpadImpl.getAddress();
        console.log("✅ Launchpad Implementation:", deployedAddresses.LaunchpadImpl, "\n");

        // ========================================
        // Step 6: Deploy SimpleBondingCurve Proxy
        // ========================================
        console.log("Step 6: Deploying SimpleBondingCurve Proxy...");
        const bondingCurveTx = await factory.deploy(
            deployedAddresses.SimpleBondingCurveImpl,
            deployer.address
        );
        const bondingCurveReceipt = await bondingCurveTx.wait();

        // Parse event to get proxy address
        const bondingCurveEvent = bondingCurveReceipt.logs.find(
            log => log.topics[0] === hre.ethers.id("Deployed(address,address,address)")
        );
        const bondingCurveProxyAddress = hre.ethers.getAddress("0x" + bondingCurveEvent.topics[1].slice(26));
        deployedAddresses.SimpleBondingCurveProxy = bondingCurveProxyAddress;
        console.log("✅ SimpleBondingCurve Proxy:", deployedAddresses.SimpleBondingCurveProxy, "\n");

        // ========================================
        // Step 7: Deploy LaunchpadLPVault Proxy
        // ========================================
        console.log("Step 7: Deploying LaunchpadLPVault Proxy...");
        const lpVaultTx = await factory.deploy(
            deployedAddresses.LaunchpadLPVaultImpl,
            deployer.address
        );
        const lpVaultReceipt = await lpVaultTx.wait();

        const lpVaultEvent = lpVaultReceipt.logs.find(
            log => log.topics[0] === hre.ethers.id("Deployed(address,address,address)")
        );
        const lpVaultProxyAddress = hre.ethers.getAddress("0x" + lpVaultEvent.topics[1].slice(26));
        deployedAddresses.LaunchpadLPVaultProxy = lpVaultProxyAddress;
        console.log("✅ LaunchpadLPVault Proxy:", deployedAddresses.LaunchpadLPVaultProxy, "\n");

        // ========================================
        // Step 8: Deploy Launchpad Proxy with Initialization
        // ========================================
        console.log("Step 8: Deploying Launchpad Proxy with initialization...");

        const initData = Launchpad.interface.encodeFunctionData("initialize", [
            deployer.address,
            config.WETH_ADDRESS,
            deployedAddresses.SimpleBondingCurveProxy,
            deployedAddresses.LaunchpadLPVaultProxy,
            hre.ethers.AbiCoder.defaultAbiCoder().encode(
                ["uint256", "uint256"],
                [config.VIRTUAL_BASE, config.VIRTUAL_QUOTE]
            )
        ]);

        console.log("Deploying at predicted address:", predictedLaunchpadAddress);
        const launchpadTx = await factory.deployDeterministicAndCall(
            deployedAddresses.LaunchpadImpl,
            deployer.address,
            launchpadSalt,
            initData,
            { gasLimit: 5000000 }
        );
        await launchpadTx.wait();

        console.log("✅ Launchpad Proxy deployed to:", predictedLaunchpadAddress, "\n");

        // ========================================
        // Step 9: Update Factory with Launchpad Addresses
        // ========================================
        console.log("Step 9: Updating Factory with launchpad addresses...");
        const factoryContract = await hre.ethers.getContractAt(
            "PushLaunchpadV2PairFactory",
            config.FACTORY_ADDRESS
        );

        const updateTx = await factoryContract.setLaunchpadAddresses(
            predictedLaunchpadAddress,
            deployedAddresses.LaunchpadLPVaultProxy,
            deployedAddresses.Distributor
        );
        await updateTx.wait();
        console.log("✅ Factory updated with launchpad addresses\n");

        // ========================================
        // Deployment Summary
        // ========================================
        console.log("==========================================");
        console.log("Deployment Summary");
        console.log("==========================================");
        console.log("\nCore System (Pre-deployed):");
        console.log("- WETH:", config.WETH_ADDRESS);
        console.log("- Router2:", config.ROUTER_ADDRESS);
        console.log("- Factory:", config.FACTORY_ADDRESS);
        console.log("- ERC1967Factory:", config.ERC1967_FACTORY);

        console.log("\nNewly Deployed:");
        console.log("- Distributor:", deployedAddresses.Distributor);

        console.log("\nImplementations:");
        console.log("- SimpleBondingCurve:", deployedAddresses.SimpleBondingCurveImpl);
        console.log("- LaunchpadLPVault:", deployedAddresses.LaunchpadLPVaultImpl);
        console.log("- Launchpad:", deployedAddresses.LaunchpadImpl);

        console.log("\n🎉 Main Contracts (Use These):");
        console.log("- SimpleBondingCurve Proxy:", deployedAddresses.SimpleBondingCurveProxy);
        console.log("- LaunchpadLPVault Proxy:", deployedAddresses.LaunchpadLPVaultProxy);
        console.log("- Launchpad Proxy:", deployedAddresses.LaunchpadProxy);
        console.log("==========================================\n");

        // Save deployment
        const deploymentsDir = path.join(__dirname, "..", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir);
        }

        const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
        const filename = path.join(deploymentsDir, `production_${timestamp}.json`);

        fs.writeFileSync(filename, JSON.stringify(deployedAddresses, null, 2));
        console.log("✅ Deployment addresses saved to:", filename, "\n");

        console.log("==========================================");
        console.log("Verification Commands:");
        console.log("==========================================");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.Distributor}`);
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.SimpleBondingCurveImpl} ${predictedLaunchpadAddress}`);
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.LaunchpadLPVaultImpl}`);
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.LaunchpadImpl} ${config.ROUTER_ADDRESS} ${deployedAddresses.Distributor}`);
        console.log("==========================================\n");

    } catch (error) {
        console.error("\n❌ Deployment failed:", error);
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
