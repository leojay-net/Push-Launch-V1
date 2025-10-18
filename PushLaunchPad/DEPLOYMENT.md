# Push Launchpad Deployment Guide

## Overview

This guide covers the complete deployment of the Push Launchpad system, including:
- Uniswap V2 Core (Factory)
- Uniswap V2 Periphery (Router)
- Launchpad System (Bonding Curve, Distributor, LP Vault, Launchpad)

## Deployment Order & Dependencies

### Circular Dependency Resolution

The system has a circular dependency:
- **SimpleBondingCurve** requires the **Launchpad** address in its constructor
- **Launchpad** requires the **BondingCurve** address in its initialize function

**Solution**: Use CREATE2 to predict the Launchpad proxy address before deployment.

### Deployment Flow

```
1. Deploy PushLaunchpadV2PairFactory
   ├─ Can use address(0) for launchpad-related addresses initially
   └─ These can be set later via setter functions (if implemented)

2. Deploy PushLaunchpadV2Router2
   ├─ Requires: Factory address
   └─ Requires: WETH address

3. Deploy Supporting Contracts
   ├─ Distributor (no dependencies)
   └─ LaunchpadLPVault (no dependencies)

4. Deploy Launchpad Implementation
   ├─ Requires: Router address
   └─ Requires: Distributor address

5. Predict Launchpad Proxy Address (using CREATE2)
   └─ Use ERC1967Factory.predictDeterministicAddress()

6. Deploy SimpleBondingCurve
   └─ Use predicted launchpad proxy address

7. Deploy Launchpad Proxy
   └─ At the predicted address using CREATE2

8. Initialize Launchpad
   ├─ Requires: Bonding Curve address
   ├─ Requires: LP Vault address
   └─ Requires: Quote Asset address
```

## Prerequisites

### 1. Environment Setup

Create a `.env` file in the `PushLaunchPad` directory:

```bash
# Required
PRIVATE_KEY=your_private_key_here
WETH_ADDRESS=0x...  # WETH contract address on your network

# Optional (defaults to WETH if not set)
QUOTE_ASSET=0x...   # The trading token (WETH, USDC, etc.)

# Optional (defaults to deployer)
DEPLOYER=0x...
LAUNCHPAD_OWNER=0x...
FEE_TO_SETTER=0x...

# Optional (bonding curve parameters)
VIRTUAL_BASE=1000000000000000000000000      # 1M tokens (1e24)
VIRTUAL_QUOTE=30000000000000000000           # 30 ETH (3e19)
GRADUATION_THRESHOLD=24000000000000000000000 # 24k tokens (24e21)
```

### 2. Install Dependencies

```bash
cd PushLaunchPad
forge install
```

### 3. Verify Compilation

```bash
forge build
```

All contracts should compile successfully.

## Deployment

### Option 1: Deploy Everything (Recommended)

```bash
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Option 2: Deploy Step-by-Step

#### Step 1: Deploy Factory

```bash
forge create src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol:PushLaunchpadV2PairFactory \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args $FEE_TO_SETTER 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 \
  --verify
```

#### Step 2: Deploy Router

```bash
forge create src/launchpad/uniswap/PushLaunchpadV2Router2.sol:PushLaunchpadV2Router2 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args $FACTORY_ADDRESS $WETH_ADDRESS \
  --verify
```

#### Step 3: Deploy Supporting Contracts

```bash
# Deploy Distributor
forge create src/launchpad/Distributor.sol:Distributor \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify

# Deploy LP Vault
forge create src/launchpad/LaunchpadLPVault.sol:LaunchpadLPVault \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify
```

#### Step 4: Deploy Launchpad System

This requires using the deployment script due to CREATE2 complexity.

## Network-Specific Addresses

### Ethereum Mainnet
```
WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
```

### Ethereum Sepolia
```
WETH: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
```

### Push Chain Testnet
```
WETH: TBD
```

### Push Chain Mainnet
```
WETH: TBD
```

## Post-Deployment

### 1. Verify All Contracts

The deployment script will automatically verify contracts if you use `--verify` flag.

### 2. Update Factory (if needed)

If the factory was deployed with zero addresses, you need to update it:

```solidity
// Note: PushLaunchpadV2PairFactory would need these setter functions
factory.setLaunchpad(launchpadProxy);
factory.setLaunchpadLp(lpVault);
factory.setLaunchpadFeeDistributor(distributor);
```

**Important**: Check if `PushLaunchpadV2PairFactory` has these setter functions. If not, you must deploy the factory AFTER the launchpad system.

### 3. Test Basic Functionality

```bash
# Test creating a token
cast send $LAUNCHPAD_ADDRESS "createToken(string,string,string,string,uint256)" \
  "Test Token" "TEST" "ipfs://..." "A test token" 1000000000000000000000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### 4. Grant Necessary Roles (if using AccessControl)

Check if any contracts need role grants:

```bash
# Example: If Launchpad has role-based access
cast send $LAUNCHPAD_ADDRESS "grantRole(bytes32,address)" \
  $(cast keccak "OPERATOR_ROLE") $OPERATOR_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

## Configuration Parameters

### Bonding Curve Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `virtualBase` | 1,000,000 tokens | Initial virtual base reserve |
| `virtualQuote` | 30 ETH | Initial virtual quote reserve |
| `graduationThreshold` | 24,000 tokens | Quote tokens needed to graduate to Uniswap |

**Formula**: 
```
Price = virtualQuote / virtualBase
Initial Price = 30 / 1,000,000 = 0.00003 ETH per token
```

### Graduation Mechanics

When a token accumulates `graduationThreshold` quote tokens through bonding curve purchases:
1. Bonding curve closes to new purchases
2. Liquidity is migrated to Uniswap V2
3. LP tokens are sent to `LaunchpadLPVault`
4. Token graduates to full trading on Uniswap

## Troubleshooting

### Issue: Address Prediction Mismatch

**Error**: `Address mismatch!` when deploying launchpad proxy

**Solution**: Ensure you're using the same salt and owner address for prediction and deployment.

### Issue: Factory Creation Fails

**Error**: Pair creation fails after deployment

**Cause**: Factory has zero addresses for launchpad references

**Solution**: 
1. Check if factory has setter functions
2. If yes, call setters after launchpad deployment
3. If no, redeploy factory after launchpad is deployed

### Issue: Initialization Reverts

**Error**: Launchpad initialization fails

**Possible Causes**:
- Quote asset is zero address
- Bonding curve address is incorrect
- Already initialized (check if proxy was initialized during deployment)

**Solution**: Check all addresses and ensure initialize is only called once.

## Security Considerations

### 1. Private Key Management

Never commit `.env` file to version control. Use:
```bash
echo ".env" >> .gitignore
```

### 2. Verify Source Code

Always verify contracts on block explorers after deployment.

### 3. Test on Testnet First

Deploy on testnet and run comprehensive tests before mainnet deployment.

### 4. Multisig for Critical Roles

Consider using a multisig wallet for:
- Launchpad owner
- Fee-to setter
- Any admin roles

### 5. Time Locks

Consider adding time locks for sensitive operations.

## Gas Optimization

Estimated gas costs (approximate):

| Contract | Deployment Gas | Estimated Cost (20 gwei) |
|----------|---------------|-------------------------|
| Factory | ~3,000,000 | ~0.06 ETH |
| Router | ~2,500,000 | ~0.05 ETH |
| Distributor | ~500,000 | ~0.01 ETH |
| LP Vault | ~500,000 | ~0.01 ETH |
| Bonding Curve | ~1,000,000 | ~0.02 ETH |
| Launchpad | ~3,000,000 | ~0.06 ETH |
| **Total** | **~10,500,000** | **~0.21 ETH** |

## Support

For issues or questions:
1. Check existing issues in the repository
2. Review the code comments in deployment scripts
3. Test on a local fork first: `forge test --fork-url $RPC_URL`

## License

MIT License - See LICENSE file for details.
