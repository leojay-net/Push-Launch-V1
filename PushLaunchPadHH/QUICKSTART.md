# 🚀 Quick Start - Deploy Launchpad to Push Chain

## TL;DR

```bash
cd PushLaunchPadHH
cp .env.example .env
# Edit .env with your PRIVATE_KEY
npm install
npx hardhat compile
npx hardhat run scripts/deploy-complete.js --network push_testnet
```

## What This Does

Deploys the complete Push Chain Launchpad system from scratch:

```
✅ ERC1967Factory          → Proxy deployment factory
✅ PairFactory              → Uniswap V2 style AMM factory
✅ Router2                  → Uniswap V2 style router
✅ Distributor              → Token distribution logic
✅ SimpleBondingCurve       → Bonding curve pricing (Impl + Proxy)
✅ LaunchpadLPVault         → LP token vault (Impl + Proxy)
✅ Launchpad                → Main launchpad contract (Impl + Proxy)
```

## Prerequisites

- ✅ Node.js & npm installed
- ✅ ~5 PC tokens in your wallet (get from https://faucet.push.org)
- ✅ WETH already deployed: `0x0d0dF7E8807430A81104EA84d926139816eC7586`

## Step-by-Step

### 1. Setup Environment

```bash
cd /Users/mac/Desktop/CODE/pushchain-Uniswap-Amm/PushLaunchPadHH

# Copy environment template
cp .env.example .env

# Edit .env file
nano .env  # or use any editor
```

Add your private key:
```
PRIVATE_KEY=0xyour_private_key_here
WETH_ADDRESS=0x0d0dF7E8807430A81104EA84d926139816eC7586
```

### 2. Install Dependencies

```bash
npm install
```

This installs:
- hardhat
- @nomicfoundation/hardhat-toolbox
- @nomicfoundation/hardhat-verify
- dotenv
- @openzeppelin/contracts

### 3. Compile Contracts

```bash
npx hardhat compile
```

Should output: `Compiled X Solidity files successfully`

### 4. Deploy!

```bash
npx hardhat run scripts/deploy-complete.js --network push_testnet
```

This will:
1. 🔮 Predict launchpad address using CREATE2
2. 🏭 Deploy PairFactory
3. 🛣️ Deploy Router2
4. 💸 Deploy Distributor
5. 📈 Deploy SimpleBondingCurve (pointing to predicted launchpad)
6. 🏦 Deploy LaunchpadLPVault
7. 🚀 Deploy Launchpad (at predicted address)
8. 📊 Deploy all proxies
9. 🔄 Update factory with launchpad addresses

**Estimated time:** ~2-3 minutes
**Gas cost:** ~3-4 PC

## Output

The script will display a beautiful summary:

```
╔════════════════════════════════════════════════════════════╗
║              🎉 DEPLOYMENT COMPLETED! 🎉                   ║
╚════════════════════════════════════════════════════════════╝

✨ PROXIES (Main Contracts - Use These!)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SimpleBondingCurve:    0x...
LaunchpadLPVault:      0x...
Launchpad:             0x...
```

Deployment addresses saved to: `deployments/complete_deployment_<timestamp>.json`

## Verification

After deployment, verify contracts on Blockscout:

```bash
# The script outputs exact verification commands
# Just copy and run them!

npx hardhat verify --network push_testnet <ADDRESS> [CONSTRUCTOR_ARGS]
```

## Troubleshooting

### "Insufficient funds"
- Get more PC from https://faucet.push.org
- Check balance: `cast balance YOUR_ADDRESS --rpc-url https://evm.rpc-testnet-donut-node1.push.org/`

### "Compilation failed"
- Make sure all dependencies are installed: `npm install`
- Check Solidity version in contracts matches hardhat.config.js (0.8.27)

### "Network error"
- Try alternative RPC: Change to `push_testnet_alt` in command
- Check Push Chain status

### "Gas estimation failed"
- The script includes manual gas limits
- If still failing, there's likely a revert in contract logic

## What's Next?

1. ✅ **Verify contracts** on block explorer
2. ✅ **Test the launchpad**:
   ```javascript
   const launchpad = await ethers.getContractAt("Launchpad", LAUNCHPAD_ADDRESS);
   await launchpad.launchToken("MyToken", "MTK", "ipfs://...", flags, { value: fee });
   ```
3. ✅ **Integrate with frontend** using the proxy addresses

## Key Addresses to Save

After deployment, you'll have these main contracts:

- **Launchpad** (main entry point) - Users interact with this
- **PairFactory** - Creates trading pairs
- **Router2** - Handles swaps and liquidity
- **Distributor** - Manages token distributions

Save these from the `deployments/` folder!

## Architecture Notes

### Why CREATE2?

SimpleBondingCurve needs the launchpad address in its constructor (immutable).
Launchpad needs the bonding curve address to initialize.

**Solution:** Predict launchpad address with CREATE2 before deploying it!

### Proxy Pattern

All main contracts use ERC1967 proxies:
- Implementation = logic contract
- Proxy = storage + points to implementation
- Allows upgrades without changing addresses

## Resources

- [Push Chain Docs](https://pushchain.github.io/push-chain-website/)
- [Hardhat Docs](https://hardhat.org/docs)
- [Push Chain Faucet](https://faucet.push.org)
- [Block Explorer](https://donut.push.network/)

---

**Questions?** Check DEPLOYMENT.md for detailed documentation.

**Ready?** Run the deploy script and launch your launchpad! 🚀
