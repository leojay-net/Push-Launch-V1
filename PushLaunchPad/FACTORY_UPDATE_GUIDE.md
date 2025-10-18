# Factory Launchpad Addresses Update Guide

## Overview

The `PushLaunchpadV2PairFactory` has been updated to support **updateable launchpad addresses**. This enables the factory to create special fee-enabled pairs when the launchpad graduates tokens to Uniswap.

## Key Changes

### 1. **Removed `immutable` Keyword**
Changed from:
```solidity
address immutable launchpad;
address immutable launchpadLp;
address immutable launchpadFeeDistributor;
```

To:
```solidity
address public launchpad;
address public launchpadLp;
address public launchpadFeeDistributor;
```

### 2. **Added Setter Function**
```solidity
function setLaunchpadAddresses(
    address _launchpad,
    address _launchpadLp,
    address _launchpadFeeDistributor
) external
```

### 3. **Added Event**
```solidity
event LaunchpadAddressesUpdated(
    address indexed launchpad,
    address indexed launchpadLp,
    address indexed launchpadFeeDistributor
);
```

## Deployment Flow

### Step 1: Initial Deployment with Zero Addresses
Deploy the factory with `address(0)` for launchpad addresses to break circular dependencies:

```bash
forge create src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol:PushLaunchpadV2PairFactory \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY \
  --constructor-args \
    $DEPLOYER_ADDRESS \
    0x0000000000000000000000000000000000000000 \
    0x0000000000000000000000000000000000000000 \
    0x0000000000000000000000000000000000000000 \
  --legacy
```

**At this stage:**
- ✅ Factory is fully functional for normal pairs
- ✅ Router can use factory to create pairs
- ❌ Launchpad pairs don't have special fee distribution yet

### Step 2: Deploy Rest of System
Deploy in order:
1. ✅ Factory (done above)
2. Router
3. Distributor
4. LP Vault
5. Launchpad Implementation
6. Launchpad Proxy
7. Bonding Curve

### Step 3: Update Factory Addresses
Once all contracts are deployed, update the factory:

```bash
# Set environment variables
export FACTORY_ADDRESS=0x...
export LAUNCHPAD_ADDRESS=0x...
export LP_VAULT_ADDRESS=0x...
export DISTRIBUTOR_ADDRESS=0x...

# Run update script
forge script script/UpdateFactoryAddresses.s.sol:UpdateFactoryAddresses \
  --rpc-url push_testnet \
  --broadcast \
  -vvv
```

**Or manually via cast:**
```bash
cast send $FACTORY_ADDRESS \
  "setLaunchpadAddresses(address,address,address)" \
  $LAUNCHPAD_ADDRESS \
  $LP_VAULT_ADDRESS \
  $DISTRIBUTOR_ADDRESS \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY
```

## How It Works

### Before Update (Normal Pairs Only)
```solidity
// In createPair():
(address _launchpadLp, address _launchpadFeeDistributor) = 
    msg.sender == launchpad  // msg.sender == address(0) → always false
        ? (launchpadLp, launchpadFeeDistributor)  // Never used
        : (address(0), address(0));                // Always this path
```

**Result:** All pairs are normal pairs with standard fees.

### After Update (Launchpad Pairs Enabled)
```solidity
// In createPair():
(address _launchpadLp, address _launchpadFeeDistributor) = 
    msg.sender == launchpad  // Now checks actual launchpad address
        ? (launchpadLp, launchpadFeeDistributor)  // Used when launchpad creates pair!
        : (address(0), address(0));                // Used for normal pairs
```

**Result:** 
- **Launchpad-created pairs** → Get special fee distribution to LP Vault + Distributor
- **Normal pairs** → Standard Uniswap V2 behavior

## What Are "Special Fee-Enabled Pairs"?

When a pair is created by the launchpad (after update), it has:

1. **Automatic Fee Distribution**: Trading fees are split between:
   - LP token holders (via LaunchpadLPVault)
   - Protocol (via Distributor)

2. **Different CREATE2 Salt**: Uses 4 parameters instead of 2:
   ```solidity
   bytes32 salt = keccak256(
       abi.encodePacked(
           token0,
           token1,
           launchpadLp,        // ← Extra parameter
           launchpadFeeDistributor  // ← Extra parameter
       )
   );
   ```

3. **Initialized with Fee Contracts**:
   ```solidity
   pair.initialize(
       token0,
       token1,
       launchpadLp,        // ← Receives LP fees
       launchpadFeeDistributor  // ← Receives protocol fees
   );
   ```

## Security Considerations

### Access Control
- Only `feeToSetter` can call `setLaunchpadAddresses()`
- Same access control as `setFeeTo()` and `setFeeToSetter()`

### Recommendation
- Update addresses **once** after full deployment
- Use a multi-sig or governance contract as `feeToSetter` for production

## Testing

Run tests to verify everything works:
```bash
forge test --summary
```

Expected: ✅ All 114 tests passing

## Verification

After updating, verify the addresses:

```bash
# Check launchpad address
cast call $FACTORY_ADDRESS "launchpad()(address)" --rpc-url push_testnet

# Check LP vault address
cast call $FACTORY_ADDRESS "launchpadLp()(address)" --rpc-url push_testnet

# Check distributor address
cast call $FACTORY_ADDRESS "launchpadFeeDistributor()(address)" --rpc-url push_testnet
```

## Example Complete Deployment

```bash
# 1. Deploy Factory with zeros
FACTORY=$(forge create src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol:PushLaunchpadV2PairFactory \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY \
  --constructor-args $DEPLOYER 0x0 0x0 0x0 \
  --legacy \
  --json | jq -r '.deployedTo')

# 2. Deploy Router
ROUTER=$(forge create src/launchpad/uniswap/PushLaunchpadV2Router2.sol:PushLaunchpadV2Router2 \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY \
  --constructor-args $FACTORY $WETH \
  --legacy \
  --json | jq -r '.deployedTo')

# 3. Deploy supporting contracts
DISTRIBUTOR=$(forge create src/launchpad/Distributor.sol:Distributor \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')

LP_VAULT=$(forge create src/launchpad/LaunchpadLPVault.sol:LaunchpadLPVault \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY \
  --legacy \
  --json | jq -r '.deployedTo')

# 4. Deploy launchpad implementation
LAUNCHPAD_IMPL=$(forge create src/launchpad/Launchpad.sol:Launchpad \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY \
  --constructor-args $ROUTER $DISTRIBUTOR \
  --legacy \
  --json | jq -r '.deployedTo')

# 5. Deploy proxy factory and launchpad proxy
# (Use ERC1967Factory to deploy proxy)

# 6. Update factory with launchpad addresses
cast send $FACTORY \
  "setLaunchpadAddresses(address,address,address)" \
  $LAUNCHPAD_PROXY \
  $LP_VAULT \
  $DISTRIBUTOR \
  --rpc-url push_testnet \
  --private-key $PRIVATE_KEY

echo "✅ Deployment complete!"
echo "Factory: $FACTORY"
echo "Router: $ROUTER"
echo "Launchpad: $LAUNCHPAD_PROXY"
```

## Benefits

### ✅ Flexible Deployment
- Solves circular dependency problem
- Deploy in logical order
- Update addresses when ready

### ✅ Special Fee Distribution
- Launchpad-graduated tokens get enhanced fee sharing
- LP token holders earn trading fees
- Protocol earns fees for sustainability

### ✅ Backward Compatible
- Existing normal pairs unaffected
- Router works with both pair types
- All tests pass

## Summary

| Feature | Before Update | After Update |
|---------|--------------|--------------|
| Normal pairs (via router) | ✅ Standard fees | ✅ Standard fees |
| Launchpad pairs | ❌ Same as normal | ✅ Special fee distribution |
| Deployment flexibility | ❌ Circular dependency | ✅ Deploy in any order |
| Address mutability | ❌ Immutable (stuck at address(0)) | ✅ Updateable by feeToSetter |

**Recommendation:** Update the factory addresses after deploying the full system to enable enhanced fee distribution for launchpad-graduated tokens! 🚀
