# Push Chain Launchpad - Hardhat Deployment

Complete deployment scripts for the Push Chain Launchpad system using Hardhat.

## 📋 Prerequisites

1. Node.js and npm installed
2. Hardhat dependencies installed
3. Push Chain testnet tokens (get from [faucet](https://faucet.push.org))
4. Private key with sufficient PC balance

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd PushLaunchPadHH
npm install
```

Required packages:
- `hardhat`
- `@nomicfoundation/hardhat-toolbox`
- `@nomicfoundation/hardhat-verify`
- `dotenv`
- `@openzeppelin/contracts`

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your details:

```bash
cp .env.example .env
```

Edit `.env`:
```
PRIVATE_KEY=your_private_key_here
WETH_ADDRESS=0x0d0dF7E8807430A81104EA84d926139816eC7586
```

⚠️ **NEVER commit your `.env` file!**

### 3. Compile Contracts

```bash
npx hardhat compile
```

## 📦 Deployment Scripts

### Complete Deployment (From Scratch)

Deploys the entire system including all core infrastructure:

```bash
npx hardhat run scripts/deploy-complete.js --network push_testnet
```

This deploys **EVERYTHING** (except WETH which is pre-deployed):
- ✅ ERC1967Factory (proxy factory)
- ✅ PushLaunchpadV2PairFactory (AMM factory)
- ✅ PushLaunchpadV2Router2 (AMM router)
- ✅ Distributor (real contract)
- ✅ SimpleBondingCurve (Implementation + Proxy)
- ✅ LaunchpadLPVault (Implementation + Proxy)
- ✅ Launchpad (Implementation + Proxy)

**Use this for:** Fresh deployment to Push Chain testnet when nothing exists

### Alternative Options

If you already have some contracts deployed:

**Option 1: With Mock Contracts** (for testing)
```bash
npx hardhat run scripts/deploy-launchpad.js --network push_testnet
```
Uses: MockDistributor, MockUniV2Router

**Option 2: With Existing Infrastructure** (if Router/Factory already deployed)
```bash
npx hardhat run scripts/deploy-production.js --network push_testnet
```
Requires: Pre-deployed Router2, Factory, ERC1967Factory

## 🏗️ Architecture & Deployment Order

The deployment follows the pattern from `test/launchpad/Launchpad.t.sol`:

### Critical: Circular Dependency Solution

**Problem:** 
- `SimpleBondingCurve` constructor needs launchpad address (immutable)
- `Launchpad` initialize needs bonding curve address

**Solution:** CREATE2 Address Prediction
1. Predict the launchpad proxy address using ERC1967Factory
2. Deploy SimpleBondingCurve with the predicted address
3. Deploy Launchpad proxy at the predicted address

### Deployment Steps

```
1. Deploy/Get ERC1967Factory
   └─> Provides deterministic proxy deployment via CREATE2

2. Predict Launchpad Proxy Address
   └─> Uses CREATE2 salt with deployer address prefix
   └─> Salt format: [20 bytes deployer][12 bytes arbitrary]

3. Deploy Distributor
   └─> Handles token distribution logic

4. Deploy SimpleBondingCurve Implementation
   └─> Constructor(predictedLaunchpadAddress) ⚠️ Critical!
   └─> Has immutable launchpad address
   └─> All functions use onlyLaunchpad modifier

5. Deploy LaunchpadLPVault Implementation
   └─> Stores LP tokens

6. Deploy Launchpad Implementation
   └─> Constructor(routerAddress, distributorAddress)

7. Deploy SimpleBondingCurve Proxy
   └─> Points to implementation from step 4

8. Deploy LaunchpadLPVault Proxy
   └─> Points to implementation from step 5

9. Deploy Launchpad Proxy with Initialization
   └─> deployDeterministicAndCall with predicted salt
   └─> Initialize with:
       - owner
       - WETH address
       - SimpleBondingCurve proxy address
       - LaunchpadLPVault proxy address
       - Bonding curve init data (virtualBase, virtualQuote)

10. Update Factory (if using real Factory)
    └─> setLaunchpadAddresses(launchpad, lpVault, distributor)
```

## 📝 Configuration

### Bonding Curve Parameters

Default values from tests:
- **Virtual Base:** 200,000,000 tokens (200M ETH in wei)
- **Virtual Quote:** 10 WETH

These create the initial bonding curve pricing.

### Network Configuration

Push Chain Testnet:
- **RPC:** https://evm.rpc-testnet-donut-node1.push.org/
- **Chain ID:** 42101
- **Explorer:** https://donut.push.network/
- **Faucet:** https://faucet.push.org

## 📂 Output

Deployment addresses are saved to `deployments/` directory:
- `deployments/push_testnet_<timestamp>.json` - Full deployment
- `deployments/production_<timestamp>.json` - Production deployment

Example:
```json
{
  "ERC1967Factory": "0x...",
  "Distributor": "0x...",
  "SimpleBondingCurveImpl": "0x...",
  "SimpleBondingCurveProxy": "0x...",
  "LaunchpadLPVaultImpl": "0x...",
  "LaunchpadLPVaultProxy": "0x...",
  "LaunchpadImpl": "0x...",
  "LaunchpadProxy": "0x..."
}
```

## ✅ Verification

After deployment, verify contracts on Blockscout:

```bash
# Verify Distributor
npx hardhat verify --network push_testnet <DISTRIBUTOR_ADDRESS>

# Verify SimpleBondingCurve Implementation (with constructor arg)
npx hardhat verify --network push_testnet <BONDING_CURVE_IMPL> <PREDICTED_LAUNCHPAD>

# Verify LaunchpadLPVault Implementation
npx hardhat verify --network push_testnet <LP_VAULT_IMPL>

# Verify Launchpad Implementation (with constructor args)
npx hardhat verify --network push_testnet <LAUNCHPAD_IMPL> <ROUTER> <DISTRIBUTOR>
```

The deployment script outputs the exact verification commands for you.

## 🧪 Testing After Deployment

You can interact with the deployed contracts:

```javascript
const launchpad = await hre.ethers.getContractAt(
  "Launchpad",
  "<LAUNCHPAD_PROXY_ADDRESS>"
);

// Launch a token
const tx = await launchpad.launchToken(
  "MyToken",
  "MTK",
  "ipfs://...",
  featureFlags,
  { value: launchFee }
);
```

## 🔍 Troubleshooting

### "DeploymentFailed" Error

This usually means initialization is reverting. Check:
1. WETH address is correct and has code
2. Bonding curve supports ERC165 and IBondingCurveMinimal interface
3. Init data is properly encoded (virtualBase, virtualQuote)

### "SaltDoesNotStartWithCaller" Error

The ERC1967Factory requires salt to start with deployer address:
```javascript
// Correct format
const deployerAddress = deployer.address.toLowerCase().slice(2);
const salt = "0x" + deployerAddress + "000000000000000000000000";
```

### Gas Estimation Failed

Try adding manual gas limit:
```javascript
{ gasLimit: 5000000 }
```

## 📚 Learn More

- [Push Chain Documentation](https://pushchain.github.io/push-chain-website/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [ERC1967 Proxy Standard](https://eips.ethereum.org/EIPS/eip-1967)
- [Solady ERC1967Factory](https://github.com/Vectorized/solady)

## 🤝 Support

If you encounter issues:
1. Check the deployment logs for specific errors
2. Verify all prerequisites are met
3. Ensure sufficient PC balance for gas
4. Review the test files for reference implementations

---

**Ready to deploy?** Run the appropriate script and watch the magic happen! 🚀
