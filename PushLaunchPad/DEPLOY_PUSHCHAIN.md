# Deploy to Push Chain Testnet

This guide walks you through deploying the Push Launchpad system to Push Chain Donut Testnet.

## Prerequisites

### 1. ✅ Foundry Configuration
Your `foundry.toml` is now configured with:
- Push Chain Testnet RPC endpoints
- BlockScout explorer for verification
- Chain ID 42101

### 2. ✅ Environment Variables
Your `.env` file is set up with:
```bash
PRIVATE_KEY=37b1ea3d158441ccde1e3f1aca4d5cc4d48359b6f87a4672f8a447379969923c
WETH9_ADDRESS=0x0d0dF7E8807430A81104EA84d926139816eC7586
PUSH_RPC_URL=https://evm.rpc-testnet-donut-node1.push.org/
```

### 3. Get Testnet Tokens

Before deploying, ensure you have testnet PC tokens for gas fees:

**Push Chain Testnet Faucet**: https://faucet.push.org

Your deployer address will be derived from your `PRIVATE_KEY`. Check your balance:

```bash
cast balance $(cast wallet address --private-key $PRIVATE_KEY) \
  --rpc-url push_testnet
```

You'll need approximately **0.5 PC** for deployment gas fees.

## Deployment Steps

### Step 1: Deploy Uniswap V2 Core & Periphery

This deploys the factory and router contracts:

```bash
forge script script/Deploy1_UniswapV2.s.sol:Deploy1_UniswapV2 \
  --rpc-url push_testnet \
  --chain 42101 \
  --broadcast \
  --verify \
  -vvvv
```

**What this does:**
- Deploys `PushLaunchpadV2PairFactory`
- Deploys `PushLaunchpadV2Router2`
- Automatically verifies on BlockScout

**Expected Output:**
```
=== Deploying Uniswap V2 System ===
Deployer: 0x...
WETH: 0x0d0dF7E8807430A81104EA84d926139816eC7586
Fee To Setter: 0x...

Deploying PushLaunchpadV2PairFactory...
Factory deployed at: 0x...

Deploying PushLaunchpadV2Router2...
Router deployed at: 0x...

=== Deployment Complete ===
Save these addresses:
export FACTORY_ADDRESS=0x...
export ROUTER_ADDRESS=0x...
```

**Save the addresses** to your `.env` file:
```bash
echo "FACTORY_ADDRESS=0x..." >> .env
echo "ROUTER_ADDRESS=0x..." >> .env
```

### Step 2: Deploy Launchpad System

This deploys the launchpad, bonding curve, and supporting contracts:

```bash
forge script script/Deploy2_LaunchpadSystem.s.sol:Deploy2_LaunchpadSystem \
  --rpc-url push_testnet \
  --chain 42101 \
  --broadcast \
  --verify \
  -vvvv
```

**What this does:**
1. Deploys `Distributor` and `LaunchpadLPVault`
2. Deploys `Launchpad` implementation
3. Predicts Launchpad proxy address using CREATE2
4. Deploys `SimpleBondingCurve` with predicted address
5. Deploys Launchpad proxy at predicted address
6. Initializes Launchpad
7. Verifies all contracts on BlockScout

**Expected Output:**
```
=== Deploying Launchpad System ===
Router: 0x...
Quote Asset: 0x0d0dF7E8807430A81104EA84d926139816eC7586

--- Step 1: Deploying Supporting Contracts ---
Deploying Distributor...
Distributor: 0x...
Deploying LaunchpadLPVault...
LP Vault: 0x...

--- Step 2: Deploying Launchpad Implementation ---
Launchpad Implementation: 0x...

--- Step 3: Predicting Launchpad Proxy Address ---
Predicted Proxy Address: 0x...

--- Step 4: Deploying Bonding Curve ---
Bonding Curve: 0x...

--- Step 5: Deploying Launchpad Proxy ---
Launchpad Proxy: 0x...
[OK] Address verification passed

--- Step 6: Initializing Launchpad ---
[OK] Launchpad initialized

=== Deployment Complete ===
Save these addresses:
export DISTRIBUTOR_ADDRESS=0x...
export LP_VAULT_ADDRESS=0x...
export BONDING_CURVE_ADDRESS=0x...
export LAUNCHPAD_IMPLEMENTATION=0x...
export LAUNCHPAD_ADDRESS=0x...
```

**Save the addresses** to your `.env` file.

## Alternative: All-in-One Deployment

If you prefer to deploy everything in one command:

```bash
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url push_testnet \
  --chain 42101 \
  --broadcast \
  --verify \
  -vvvv
```

## Verify Deployment

After deployment, verify everything is working:

### 1. Check Contract Verification

Visit the Push Chain BlockScout explorer:
- **Factory**: `https://donut.push.network/address/FACTORY_ADDRESS`
- **Router**: `https://donut.push.network/address/ROUTER_ADDRESS`
- **Launchpad**: `https://donut.push.network/address/LAUNCHPAD_ADDRESS`

You should see a green checkmark ✓ indicating verified contracts.

### 2. Verify Contract State

```bash
# Check launchpad owner
cast call $LAUNCHPAD_ADDRESS "owner()" --rpc-url push_testnet

# Check bonding curve
cast call $LAUNCHPAD_ADDRESS "currentBondingCurve()(address)" --rpc-url push_testnet

# Check quote asset (should be WETH9)
cast call $LAUNCHPAD_ADDRESS "currentQuoteAsset()(address)" --rpc-url push_testnet

# Check router in launchpad
cast call $LAUNCHPAD_ADDRESS "uniV2Router()(address)" --rpc-url push_testnet
```

Expected outputs:
- Owner should be your deployer address
- Bonding curve should be the deployed SimpleBondingCurve address
- Quote asset should be `0x0d0dF7E8807430A81104EA84d926139816eC7586` (WETH9)
- Router should be your deployed router address

## Test Token Creation

Create a test token to verify the system works:

```bash
# Approve WETH spending first (if needed)
cast send $WETH9_ADDRESS "approve(address,uint256)" \
  $LAUNCHPAD_ADDRESS \
  1000000000000000000000 \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY

# Create a token
cast send $LAUNCHPAD_ADDRESS \
  "createToken(string,string,string,string,uint256)" \
  "Test Token" \
  "TEST" \
  "ipfs://QmTest..." \
  "A test token for Push Launchpad" \
  1000000000000000000000000 \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY \
  --gas-limit 5000000
```

Check the transaction on BlockScout and look for the `TokenCreated` event.

## Troubleshooting

### Deployment Fails: "Insufficient funds"

**Solution**: Get more testnet PC tokens from the faucet:
```bash
# Check your balance first
cast balance $(cast wallet address --private-key $PRIVATE_KEY) \
  --rpc-url push_testnet
```

Visit https://faucet.push.org to get testnet tokens.

### Deployment Fails: "Address mismatch"

**Solution**: Clean and rebuild:
```bash
forge clean
forge build
# Try deployment again
```

### Verification Fails

**Solution**: Manually verify using the BlockScout UI:
1. Go to `https://donut.push.network/address/YOUR_CONTRACT_ADDRESS`
2. Click "Verify & Publish"
3. Upload your contract source code

Or retry verification:
```bash
forge verify-contract \
  --chain 42101 \
  --verifier blockscout \
  YOUR_CONTRACT_ADDRESS \
  src/path/to/Contract.sol:ContractName
```

### Transaction Reverts

Check the transaction on BlockScout for detailed error messages:
```bash
# Get transaction receipt
cast receipt YOUR_TX_HASH --rpc-url push_testnet
```

### Stack Too Deep Error

This should be fixed in the deployment scripts, but if you encounter it:
```bash
# Add to foundry.toml under [profile.default]
via_ir = true
```

## Gas Cost Summary

Approximate gas costs on Push Chain (may vary):

| Contract | Estimated Gas | ~Cost in PC (if gas price = 1 gwei) |
|----------|--------------|--------------------------------------|
| Factory | ~3,000,000 | ~0.003 PC |
| Router | ~2,500,000 | ~0.0025 PC |
| Distributor | ~500,000 | ~0.0005 PC |
| LP Vault | ~500,000 | ~0.0005 PC |
| Bonding Curve | ~1,000,000 | ~0.001 PC |
| Launchpad | ~3,000,000 | ~0.003 PC |
| **Total** | **~10.5M** | **~0.01 PC** |

Actual costs depend on network conditions.

## Next Steps

After successful deployment:

1. **Update Frontend**: Update your frontend with the deployed contract addresses
2. **Test Token Launches**: Create and test token launches on testnet
3. **Monitor Events**: Watch for `TokenCreated`, `TokenGraduated`, and swap events
4. **Security Audit**: Before mainnet, ensure security audits are complete
5. **Mainnet Preparation**: Plan mainnet deployment with proper security measures

## Useful Commands

```bash
# Check deployer balance
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url push_testnet

# Get transaction details
cast tx YOUR_TX_HASH --rpc-url push_testnet

# Call view functions
cast call CONTRACT_ADDRESS "functionName()" --rpc-url push_testnet

# Send transactions
cast send CONTRACT_ADDRESS "functionName(args)" ARGS --rpc-url push_testnet --private-key $PRIVATE_KEY

# Get logs
cast logs --address CONTRACT_ADDRESS --rpc-url push_testnet
```

## Security Reminders

⚠️ **IMPORTANT**:
- Never commit your `.env` file to git
- Use a separate account for testnet deployments
- Never reuse testnet private keys on mainnet
- Keep your private keys secure
- Use a hardware wallet or multisig for mainnet deployments

## Support

- **Push Chain Docs**: https://pushchain.github.io/push-chain-website/
- **Block Explorer**: https://donut.push.network
- **Testnet Faucet**: https://faucet.push.org
- **Push Chain Discord**: [Join for support]

---

**Ready to deploy? Run Step 1 now! 🚀**
