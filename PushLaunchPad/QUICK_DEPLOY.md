# Quick Deployment Reference

## Prerequisites

1. Set up your `.env` file (copy from `.env.example`)
2. Fund your deployer address with native tokens for gas
3. Ensure you have the WETH address for your network

## Option 1: All-in-One Deployment

Deploy everything in a single script:

```bash
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $PUSH_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

## Option 2: Step-by-Step Deployment (Recommended)

### Step 1: Deploy Uniswap V2

```bash
forge script script/Deploy1_UniswapV2.s.sol:Deploy1_UniswapV2 \
  --rpc-url $PUSH_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

Save the output addresses to your `.env`:
```bash
export FACTORY_ADDRESS=0x...
export ROUTER_ADDRESS=0x...
```

### Step 2: Deploy Launchpad System

```bash
forge script script/Deploy2_LaunchpadSystem.s.sol:Deploy2_LaunchpadSystem \
  --rpc-url $PUSH_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

Save the output addresses:
```bash
export DISTRIBUTOR_ADDRESS=0x...
export LP_VAULT_ADDRESS=0x...
export BONDING_CURVE_ADDRESS=0x...
export LAUNCHPAD_IMPLEMENTATION=0x...
export LAUNCHPAD_ADDRESS=0x...
```

## Deployment Architecture

```
UniswapV2 Deployment:
┌─────────────────────────────┐
│ PushLaunchpadV2PairFactory  │ ← First (with zero addresses)
└─────────────────────────────┘
            ↓
┌─────────────────────────────┐
│ PushLaunchpadV2Router2      │ ← Second (needs Factory)
└─────────────────────────────┘

Launchpad Deployment (Circular Dependency Resolution):
┌─────────────────────────────┐
│ Distributor                 │ ← Supporting contracts
│ LaunchpadLPVault            │
└─────────────────────────────┘
            ↓
┌─────────────────────────────┐
│ Launchpad Implementation    │ ← Needs Router + Distributor
└─────────────────────────────┘
            ↓
┌─────────────────────────────┐
│ ERC1967Factory.predict()    │ ← Predict proxy address
└─────────────────────────────┘
            ↓
┌─────────────────────────────┐
│ SimpleBondingCurve          │ ← Uses predicted address
└─────────────────────────────┘
            ↓
┌─────────────────────────────┐
│ Launchpad Proxy (CREATE2)   │ ← Deploy at predicted address
└─────────────────────────────┘
            ↓
┌─────────────────────────────┐
│ Launchpad.initialize()      │ ← Initialize with BondingCurve
└─────────────────────────────┘
```

## Environment Variables

### Required
```bash
PRIVATE_KEY=0x...
WETH_ADDRESS=0x...
PUSH_RPC_URL=https://...
```

### Optional (will use defaults)
```bash
DEPLOYER=0x...
LAUNCHPAD_OWNER=0x...
FEE_TO_SETTER=0x...
QUOTE_ASSET=0x...  # Defaults to WETH
VIRTUAL_BASE=1000000000000000000000000   # 1M tokens
VIRTUAL_QUOTE=30000000000000000000        # 30 ETH
```

## Testing Locally

Test on a local fork first:

```bash
# Start local fork
anvil --fork-url $PUSH_RPC_URL

# In another terminal, deploy
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vvvv
```

## Verify Deployment

After deployment, verify the contracts are working:

```bash
# Check launchpad owner
cast call $LAUNCHPAD_ADDRESS "owner()" --rpc-url $PUSH_RPC_URL

# Check bonding curve
cast call $LAUNCHPAD_ADDRESS "currentBondingCurve()" --rpc-url $PUSH_RPC_URL

# Check quote asset
cast call $LAUNCHPAD_ADDRESS "currentQuoteAsset()" --rpc-url $PUSH_RPC_URL
```

## Post-Deployment (Optional)

If the factory was deployed with zero addresses for launchpad references, you may need to update them (if setter functions exist):

```bash
# Check if factory has these functions first
cast call $FACTORY_ADDRESS "launchpad()" --rpc-url $PUSH_RPC_URL

# If it returns 0x0...0, and setter functions exist:
cast send $FACTORY_ADDRESS "setLaunchpad(address)" $LAUNCHPAD_ADDRESS \
  --rpc-url $PUSH_RPC_URL \
  --private-key $PRIVATE_KEY
```

## Troubleshooting

### "Address mismatch!" error
- The CREATE2 prediction didn't match the actual deployment
- Ensure you're using the same salt and owner for both prediction and deployment
- Clean and rebuild: `forge clean && forge build`

### "Stack too deep" error
- This should be fixed in Deploy2_LaunchpadSystem.s.sol
- If you still see it, compile with `--via-ir` flag

### Initialization fails
- Check all addresses are correct
- Ensure the bonding curve address matches what the launchpad expects
- Verify quote asset is a valid ERC20 token

## Gas Estimates

Approximate gas costs at 20 gwei:

| Step | Gas | Cost (ETH) |
|------|-----|------------|
| Factory | 3M | 0.06 |
| Router | 2.5M | 0.05 |
| Distributor | 500K | 0.01 |
| LP Vault | 500K | 0.01 |
| Launchpad Impl | 2.5M | 0.05 |
| Bonding Curve | 1M | 0.02 |
| Proxy Deploy | 500K | 0.01 |
| Initialize | 200K | 0.004 |
| **Total** | **~10.7M** | **~0.21 ETH** |

Actual costs will vary based on network gas prices.

## Need Help?

- Check DEPLOYMENT.md for detailed explanations
- Review the deployment scripts for inline comments
- Test on a local fork before mainnet deployment
