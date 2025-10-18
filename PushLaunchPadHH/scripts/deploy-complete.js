const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * COMPLETE FROM-SCRATCH DEPLOYMENT
 * Push Chain Launchpad - Full System Deployment
 * 
 * Deploys the entire system including:
 * - ERC1967Factory (for proxy deployments)
 * - PushLaunchpadV2PairFactory (AMM Factory)
 * - PushLaunchpadV2Router2 (AMM Router)
 * - Distributor
 * - SimpleBondingCurve (Implementation + Proxy)
 * - LaunchpadLPVault (Implementation + Proxy)
 * - Launchpad (Implementation + Proxy)
 * 
 * Assumes ONLY WETH is already deployed on the network.
 */

async function main() {
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║  Push Chain Launchpad - Complete Deployment               ║");
    console.log("║  Starting from Scratch (except WETH)                       ║");
    console.log("╚════════════════════════════════════════════════════════════╝\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("👤 Deploying with account:", deployer.address);

    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("💰 Account balance:", hre.ethers.formatEther(balance), "PC");

    if (balance < hre.ethers.parseEther("1")) {
        console.warn("⚠️  Warning: Low balance! You may need more PC tokens.");
        console.warn("   Get testnet tokens from: https://faucet.push.org\n");
    }
    console.log("");

    // ========================================
    // Configuration
    // ========================================
    let WETH_ADDRESS = process.env.WETH_ADDRESS || null;
    const VIRTUAL_BASE = hre.ethers.parseEther("200000000"); // 200M tokens
    const VIRTUAL_QUOTE = hre.ethers.parseEther("10"); // 10 WETH

    console.log("⚙️  Configuration:");
    console.log("   WETH Address:", WETH_ADDRESS || "<to be deployed>");
    console.log("   Virtual Base:", hre.ethers.formatEther(VIRTUAL_BASE), "tokens");
    console.log("   Virtual Quote:", hre.ethers.formatEther(VIRTUAL_QUOTE), "WETH\n");

    const deployedAddresses = {
        deployer: deployer.address,
        network: "Push Chain Testnet",
        chainId: 42101,
        timestamp: new Date().toISOString()
    };

    try {
        // ========================================
        // STEP 0: Deploy WETH (if needed)
        // ========================================
        if (!WETH_ADDRESS) {
            console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            console.log("💧 STEP 0: Deploying MintableWETH (Test WETH)");
            console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

            const MintableWETH = await hre.ethers.getContractFactory("MintableWETH");
            const weth = await MintableWETH.deploy();
            await weth.waitForDeployment();
            WETH_ADDRESS = await weth.getAddress();
            deployedAddresses.WETH = WETH_ADDRESS;
            deployedAddresses.WETH_Deployed = true;

            console.log("✅ MintableWETH:", WETH_ADDRESS);

            // Mint some initial WETH to deployer for testing
            const mintAmount = hre.ethers.parseEther("100");
            const mintTx = await weth.mint(deployer.address, mintAmount);
            await mintTx.wait();
            const wethBal = await weth.balanceOf(deployer.address);
            console.log("   Minted:", hre.ethers.formatEther(mintAmount), "WETH to", deployer.address);
            console.log("   Deployer WETH balance:", hre.ethers.formatEther(wethBal));
            console.log("");
        } else {
            console.log("ℹ️  Using provided WETH address:", WETH_ADDRESS);
            deployedAddresses.WETH = WETH_ADDRESS;
        }

        // ========================================
        // STEP 1: Deploy ERC1967Factory
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("📦 STEP 1: Deploying ERC1967Factory");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const ERC1967Factory = await hre.ethers.getContractFactory("ERC1967Factory");
        const erc1967Factory = await ERC1967Factory.deploy();
        await erc1967Factory.waitForDeployment();
        deployedAddresses.ERC1967Factory = await erc1967Factory.getAddress();

        console.log("✅ ERC1967Factory:", deployedAddresses.ERC1967Factory);
        console.log("   Purpose: Deploys deterministic ERC1967 proxies using CREATE2\n");

        // ========================================
        // STEP 2: Predict Launchpad Address
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🔮 STEP 2: Predicting Launchpad Proxy Address");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        // Create salt: [20 bytes deployer address][12 bytes zeros]
        const deployerAddress = deployer.address.toLowerCase().slice(2);
        const launchpadSalt = "0x" + deployerAddress + "000000000000000000000000";

        console.log("   Salt:", launchpadSalt);
        console.log("   (First 20 bytes = deployer address - required by ERC1967Factory)");

        const predictedLaunchpadAddress = await erc1967Factory.predictDeterministicAddress(launchpadSalt);
        deployedAddresses.LaunchpadProxy_Predicted = predictedLaunchpadAddress;

        console.log("✅ Predicted Launchpad Address:", predictedLaunchpadAddress);
        console.log("   This address will be used in SimpleBondingCurve constructor\n");

        // ========================================
        // STEP 3: Deploy PushLaunchpadV2PairFactory
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🏭 STEP 3: Deploying PushLaunchpadV2PairFactory");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        // Note: Factory needs launchpad addresses, but we'll update them later
        // For now, deploy with placeholder addresses
        const PairFactory = await hre.ethers.getContractFactory("PushLaunchpadV2PairFactory");
        const pairFactory = await PairFactory.deploy(
            deployer.address,  // feeToSetter
            hre.ethers.ZeroAddress,  // launchpad (will update later)
            hre.ethers.ZeroAddress,  // launchpadLp (will update later)
            hre.ethers.ZeroAddress   // launchpadFeeDistributor (will update later)
        );
        await pairFactory.waitForDeployment();
        deployedAddresses.PairFactory = await pairFactory.getAddress();

        console.log("✅ PushLaunchpadV2PairFactory:", deployedAddresses.PairFactory);
        console.log("   Fee Setter:", deployer.address);
        console.log("   (Launchpad addresses will be updated after launchpad deployment)\n");

        // ========================================
        // STEP 4: Deploy PushLaunchpadV2Router2
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🛣️  STEP 4: Deploying PushLaunchpadV2Router2");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const Router2 = await hre.ethers.getContractFactory("PushLaunchpadV2Router2");
        const router2 = await Router2.deploy(
            deployedAddresses.PairFactory,
            WETH_ADDRESS
        );
        await router2.waitForDeployment();
        deployedAddresses.Router2 = await router2.getAddress();

        console.log("✅ PushLaunchpadV2Router2:", deployedAddresses.Router2);
        console.log("   Factory:", deployedAddresses.PairFactory);
        console.log("   WETH:", WETH_ADDRESS, "\n");

        // ========================================
        // STEP 5: Deploy Distributor
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("💸 STEP 5: Deploying Distributor");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const Distributor = await hre.ethers.getContractFactory("Distributor");
        const distributor = await Distributor.deploy();
        await distributor.waitForDeployment();
        deployedAddresses.Distributor = await distributor.getAddress();

        console.log("✅ Distributor:", deployedAddresses.Distributor);
        console.log("   Handles token distribution logic\n");

        // ========================================
        // STEP 6: Deploy SimpleBondingCurve Implementation
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("📈 STEP 6: Deploying SimpleBondingCurve Implementation");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const SimpleBondingCurve = await hre.ethers.getContractFactory("SimpleBondingCurve");
        const bondingCurveImpl = await SimpleBondingCurve.deploy(predictedLaunchpadAddress);
        await bondingCurveImpl.waitForDeployment();
        deployedAddresses.SimpleBondingCurveImpl = await bondingCurveImpl.getAddress();

        console.log("✅ SimpleBondingCurve Implementation:", deployedAddresses.SimpleBondingCurveImpl);
        console.log("   Launchpad (immutable):", predictedLaunchpadAddress);
        console.log("   ⚠️  Critical: Uses predicted launchpad address!\n");

        // ========================================
        // STEP 7: Deploy LaunchpadLPVault Implementation
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🏦 STEP 7: Deploying LaunchpadLPVault Implementation");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const LaunchpadLPVault = await hre.ethers.getContractFactory("LaunchpadLPVault");
        const lpVaultImpl = await LaunchpadLPVault.deploy();
        await lpVaultImpl.waitForDeployment();
        deployedAddresses.LaunchpadLPVaultImpl = await lpVaultImpl.getAddress();

        console.log("✅ LaunchpadLPVault Implementation:", deployedAddresses.LaunchpadLPVaultImpl);
        console.log("   Stores LP tokens from graduated launches\n");

        // ========================================
        // STEP 8: Deploy Launchpad Implementation
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🚀 STEP 8: Deploying Launchpad Implementation");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const Launchpad = await hre.ethers.getContractFactory("Launchpad");
        const launchpadImpl = await Launchpad.deploy(
            deployedAddresses.Router2,
            deployedAddresses.Distributor
        );
        await launchpadImpl.waitForDeployment();
        deployedAddresses.LaunchpadImpl = await launchpadImpl.getAddress();

        console.log("✅ Launchpad Implementation:", deployedAddresses.LaunchpadImpl);
        console.log("   Router:", deployedAddresses.Router2);
        console.log("   Distributor:", deployedAddresses.Distributor, "\n");

        // ========================================
        // STEP 9: Deploy SimpleBondingCurve Proxy
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("📊 STEP 9: Deploying SimpleBondingCurve Proxy");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const bondingCurveTx = await erc1967Factory.deploy(
            deployedAddresses.SimpleBondingCurveImpl,
            deployer.address
        );
        const bondingCurveReceipt = await bondingCurveTx.wait();

        // Extract proxy address from Deployed event
        const bondingCurveEvent = bondingCurveReceipt.logs.find(
            log => {
                try {
                    const parsed = erc1967Factory.interface.parseLog(log);
                    return parsed && parsed.name === "Deployed";
                } catch { return false; }
            }
        );

        if (!bondingCurveEvent) {
            throw new Error("Could not find Deployed event for SimpleBondingCurve proxy");
        }

        const parsedEvent = erc1967Factory.interface.parseLog(bondingCurveEvent);
        const bondingCurveProxyAddress = parsedEvent.args.proxy;
        deployedAddresses.SimpleBondingCurveProxy = bondingCurveProxyAddress;

        console.log("✅ SimpleBondingCurve Proxy:", deployedAddresses.SimpleBondingCurveProxy);
        console.log("   Implementation:", deployedAddresses.SimpleBondingCurveImpl);
        console.log("   Admin:", deployer.address, "\n");

        // ========================================
        // STEP 10: Deploy LaunchpadLPVault Proxy
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🏦 STEP 10: Deploying LaunchpadLPVault Proxy");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const lpVaultTx = await erc1967Factory.deploy(
            deployedAddresses.LaunchpadLPVaultImpl,
            deployer.address
        );
        const lpVaultReceipt = await lpVaultTx.wait();

        const lpVaultEvent = lpVaultReceipt.logs.find(
            log => {
                try {
                    const parsed = erc1967Factory.interface.parseLog(log);
                    return parsed && parsed.name === "Deployed";
                } catch { return false; }
            }
        );

        if (!lpVaultEvent) {
            throw new Error("Could not find Deployed event for LaunchpadLPVault proxy");
        }

        const parsedLpVaultEvent = erc1967Factory.interface.parseLog(lpVaultEvent);
        const lpVaultProxyAddress = parsedLpVaultEvent.args.proxy;
        deployedAddresses.LaunchpadLPVaultProxy = lpVaultProxyAddress;

        console.log("✅ LaunchpadLPVault Proxy:", deployedAddresses.LaunchpadLPVaultProxy);
        console.log("   Implementation:", deployedAddresses.LaunchpadLPVaultImpl);
        console.log("   Admin:", deployer.address, "\n");

        // ========================================
        // STEP 11: Deploy Launchpad Proxy with Initialization
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🎯 STEP 11: Deploying Launchpad Proxy with Initialization");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        // Encode bonding curve init data
        const bondingCurveInitData = hre.ethers.AbiCoder.defaultAbiCoder().encode(
            ["uint256", "uint256"],
            [VIRTUAL_BASE, VIRTUAL_QUOTE]
        );

        // Encode launchpad initialization call
        const initData = Launchpad.interface.encodeFunctionData("initialize", [
            deployer.address,  // owner
            WETH_ADDRESS,  // quoteAsset
            deployedAddresses.SimpleBondingCurveProxy,  // bondingCurve
            deployedAddresses.LaunchpadLPVaultProxy,  // launchpadLPVault
            bondingCurveInitData  // bondingCurveInitData
        ]);

        console.log("   Initialization Parameters:");
        console.log("   - Owner:", deployer.address);
        console.log("   - Quote Asset (WETH):", WETH_ADDRESS);
        console.log("   - Bonding Curve:", deployedAddresses.SimpleBondingCurveProxy);
        console.log("   - LP Vault:", deployedAddresses.LaunchpadLPVaultProxy);
        console.log("   - Virtual Base:", hre.ethers.formatEther(VIRTUAL_BASE));
        console.log("   - Virtual Quote:", hre.ethers.formatEther(VIRTUAL_QUOTE));
        console.log("");
        console.log("   Deploying at predicted address:", predictedLaunchpadAddress);

        const launchpadTx = await erc1967Factory.deployDeterministicAndCall(
            deployedAddresses.LaunchpadImpl,
            deployer.address,
            launchpadSalt,
            initData,
            { gasLimit: 5000000 }
        );
        const launchpadReceipt = await launchpadTx.wait();

        deployedAddresses.LaunchpadProxy = predictedLaunchpadAddress;

        console.log("✅ Launchpad Proxy:", deployedAddresses.LaunchpadProxy);
        console.log("   Implementation:", deployedAddresses.LaunchpadImpl);
        console.log("   Admin:", deployer.address);
        console.log("   ✨ Successfully initialized with bonding curve parameters!\n");

        // ========================================
        // STEP 12: Initialize Distributor
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🔌 STEP 12: Initializing Distributor with Launchpad");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const distributorInitTx = await distributor.initialize(
            deployedAddresses.LaunchpadProxy
        );
        await distributorInitTx.wait();

        const configuredLaunchpad = await distributor.launchpad();
        console.log("✅ Distributor initialized:");
        console.log("   - Launchpad set to:", configuredLaunchpad);
        console.log("   - (Should match Launchpad proxy above)\n");

        // ========================================
        // STEP 13: Update Factory with Launchpad Addresses
        // ========================================
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🔄 STEP 13: Updating Factory with Launchpad Addresses");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        const updateTx = await pairFactory.setLaunchpadAddresses(
            deployedAddresses.LaunchpadProxy,
            deployedAddresses.LaunchpadLPVaultProxy,
            deployedAddresses.Distributor
        );
        await updateTx.wait();

        console.log("✅ Factory Updated:");
        console.log("   - Launchpad:", deployedAddresses.LaunchpadProxy);
        console.log("   - LP Vault:", deployedAddresses.LaunchpadLPVaultProxy);
        console.log("   - Distributor:", deployedAddresses.Distributor, "\n");

        // ========================================
        // Deployment Summary
        // ========================================
        console.log("\n");
        console.log("╔════════════════════════════════════════════════════════════╗");
        console.log("║              🎉 DEPLOYMENT COMPLETED! 🎉                   ║");
        console.log("╚════════════════════════════════════════════════════════════╝");
        console.log("");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("📋 INFRASTRUCTURE");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("WETH:                  ", deployedAddresses.WETH);
        console.log("ERC1967Factory:        ", deployedAddresses.ERC1967Factory);
        console.log("PairFactory:           ", deployedAddresses.PairFactory);
        console.log("Router2:               ", deployedAddresses.Router2);
        console.log("Distributor:           ", deployedAddresses.Distributor);
        console.log("");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🔧 IMPLEMENTATIONS (Logic Contracts)");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("SimpleBondingCurve:    ", deployedAddresses.SimpleBondingCurveImpl);
        console.log("LaunchpadLPVault:      ", deployedAddresses.LaunchpadLPVaultImpl);
        console.log("Launchpad:             ", deployedAddresses.LaunchpadImpl);
        console.log("");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("✨ PROXIES (Main Contracts - Use These!)");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("SimpleBondingCurve:    ", deployedAddresses.SimpleBondingCurveProxy);
        console.log("LaunchpadLPVault:      ", deployedAddresses.LaunchpadLPVaultProxy);
        console.log("Launchpad:             ", deployedAddresses.LaunchpadProxy);
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("");

        // Save deployment
        const deploymentsDir = path.join(__dirname, "..", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir);
        }

        const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
        const filename = path.join(deploymentsDir, `complete_deployment_${timestamp}.json`);

        fs.writeFileSync(filename, JSON.stringify(deployedAddresses, null, 2));
        console.log("💾 Deployment addresses saved to:", filename);
        console.log("");

        // Verification commands
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("🔍 VERIFICATION COMMANDS");
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("");
        console.log("# Verify ERC1967Factory");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.ERC1967Factory}`);
        console.log("");
        console.log("# Verify PairFactory");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.PairFactory} \\`);
        console.log(`  "${deployer.address}" \\`);
        console.log(`  "${hre.ethers.ZeroAddress}" \\`);
        console.log(`  "${hre.ethers.ZeroAddress}" \\`);
        console.log(`  "${hre.ethers.ZeroAddress}"`);
        console.log("");
        console.log("# Verify Router2");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.Router2} \\`);
        console.log(`  "${deployedAddresses.PairFactory}" \\`);
        console.log(`  "${WETH_ADDRESS}"`);
        console.log("");
        console.log("# Verify Distributor");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.Distributor}`);
        console.log("");
        console.log("# Verify SimpleBondingCurve Implementation");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.SimpleBondingCurveImpl} \\`);
        console.log(`  "${predictedLaunchpadAddress}"`);
        console.log("");
        console.log("# Verify LaunchpadLPVault Implementation");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.LaunchpadLPVaultImpl}`);
        console.log("");
        console.log("# Verify Launchpad Implementation");
        console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.LaunchpadImpl} \\`);
        console.log(`  "${deployedAddresses.Router2}" \\`);
        console.log(`  "${deployedAddresses.Distributor}"`);
        console.log("");
        if (deployedAddresses.WETH_Deployed) {
            console.log("# Verify MintableWETH (optional)");
            console.log(`npx hardhat verify --network push_testnet ${deployedAddresses.WETH}`);
            console.log("");
        }
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("");

        console.log("🎊 Next Steps:");
        console.log("   1. Verify contracts on block explorer (commands above)");
        console.log("   2. Run a quick validation: distributor.launchpad() should equal Launchpad proxy");
        console.log("   3. Test launching a token through the launchpad");
        console.log("   4. Share the launchpad proxy address with frontend team");
        console.log("");
        console.log("╔════════════════════════════════════════════════════════════╗");
        console.log("║  Deployment script completed successfully! 🚀              ║");
        console.log("╚════════════════════════════════════════════════════════════╝");
        console.log("");

    } catch (error) {
        console.error("\n");
        console.error("╔════════════════════════════════════════════════════════════╗");
        console.error("║  ❌ DEPLOYMENT FAILED ❌                                   ║");
        console.error("╚════════════════════════════════════════════════════════════╝");
        console.error("");
        console.error("Error:", error.message);
        if (error.error) {
            console.error("Details:", error.error);
        }
        console.error("");
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
