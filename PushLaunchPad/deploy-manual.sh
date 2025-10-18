#!/bin/bash

# Manual deployment script for Push Chain
# This script deploys contracts using cast send directly

set -e

# Load environment variables
source .env

# Configuration
RPC_URL="https://evm.rpc-testnet-donut-node1.push.org/"
CHAIN_ID=42101

echo "=== Push Launchpad Manual Deployment ==="
echo "RPC URL: $RPC_URL"
echo "Chain ID: $CHAIN_ID"
echo "WETH: $WETH9_ADDRESS"
echo ""

# Get deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Deployer: $DEPLOYER"

# Check balance
BALANCE=$(cast balance $DEPLOYER --rpc-url $RPC_URL)
echo "Balance: $(cast to-unit $BALANCE ether) PC"
echo ""

# Step 1: Deploy Factory
echo "=== Step 1: Deploying PushLaunchpadV2PairFactory ==="
FACTORY_BYTECODE=$(forge inspect src/launchpad/uniswap/PushLaunchpadV2PairFactory.sol:PushLaunchpadV2PairFactory bytecode)
FACTORY_CONSTRUCTOR=$(cast abi-encode "constructor(address,address,address,address)" $DEPLOYER 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000)

echo "Deploying Factory..."
FACTORY_TX=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --create "${FACTORY_BYTECODE}${FACTORY_CONSTRUCTOR:2}" --legacy --gas-limit 10000000 --json)
FACTORY_ADDRESS=$(echo $FACTORY_TX | jq -r '.contractAddress')
echo "Factory deployed at: $FACTORY_ADDRESS"
echo ""

# Step 2: Deploy Router
echo "=== Step 2: Deploying PushLaunchpadV2Router2 ==="
ROUTER_BYTECODE=$(forge inspect src/launchpad/uniswap/PushLaunchpadV2Router2.sol:PushLaunchpadV2Router2 bytecode)
ROUTER_CONSTRUCTOR=$(cast abi-encode "constructor(address,address)" $FACTORY_ADDRESS $WETH9_ADDRESS)

echo "Deploying Router..."
ROUTER_TX=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --create "${ROUTER_BYTECODE}${ROUTER_CONSTRUCTOR:2}" --legacy --gas-limit 10000000 --json)
ROUTER_ADDRESS=$(echo $ROUTER_TX | jq -r '.contractAddress')
echo "Router deployed at: $ROUTER_ADDRESS"
echo ""

# Step 3: Deploy Distributor
echo "=== Step 3: Deploying Distributor ==="
DISTRIBUTOR_BYTECODE=$(forge inspect src/launchpad/Distributor.sol:Distributor bytecode)

echo "Deploying Distributor..."
DISTRIBUTOR_TX=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --create "$DISTRIBUTOR_BYTECODE" --legacy --gas-limit 10000000 --json)
DISTRIBUTOR_ADDRESS=$(echo $DISTRIBUTOR_TX | jq -r '.contractAddress')
echo "Distributor deployed at: $DISTRIBUTOR_ADDRESS"
echo ""

# Step 4: Deploy LP Vault
echo "=== Step 4: Deploying LaunchpadLPVault ==="
LPVAULT_BYTECODE=$(forge inspect src/launchpad/LaunchpadLPVault.sol:LaunchpadLPVault bytecode)

echo "Deploying LP Vault..."
LPVAULT_TX=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --create "$LPVAULT_BYTECODE" --legacy --gas-limit 10000000 --json)
LPVAULT_ADDRESS=$(echo $LPVAULT_TX | jq -r '.contractAddress')
echo "LP Vault deployed at: $LPVAULT_ADDRESS"
echo ""

# Step 5: Deploy Launchpad Implementation
echo "=== Step 5: Deploying Launchpad Implementation ==="
LAUNCHPAD_BYTECODE=$(forge inspect src/launchpad/Launchpad.sol:Launchpad bytecode)
LAUNCHPAD_CONSTRUCTOR=$(cast abi-encode "constructor(address,address)" $ROUTER_ADDRESS $DISTRIBUTOR_ADDRESS)

echo "Deploying Launchpad Implementation..."
LAUNCHPAD_IMPL_TX=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --create "${LAUNCHPAD_BYTECODE}${LAUNCHPAD_CONSTRUCTOR:2}" --legacy --gas-limit 10000000 --json)
LAUNCHPAD_IMPL_ADDRESS=$(echo $LAUNCHPAD_IMPL_TX | jq -r '.contractAddress')
echo "Launchpad Implementation deployed at: $LAUNCHPAD_IMPL_ADDRESS"
echo ""

# Step 6: Deploy ERC1967Factory
echo "=== Step 6: Deploying ERC1967Factory ==="
PROXY_FACTORY_BYTECODE=$(forge inspect lib/solady/src/utils/ERC1967Factory.sol:ERC1967Factory bytecode)

echo "Deploying Proxy Factory..."
PROXY_FACTORY_TX=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --create "$PROXY_FACTORY_BYTECODE" --legacy --gas-limit 10000000 --json)
PROXY_FACTORY_ADDRESS=$(echo $PROXY_FACTORY_TX | jq -r '.contractAddress')
echo "Proxy Factory deployed at: $PROXY_FACTORY_ADDRESS"
echo ""

# Step 7: Calculate predicted launchpad proxy address
echo "=== Step 7: Predicting Launchpad Proxy Address ==="
SALT=$(cast to-bytes32 $(cast to-uint256 $DEPLOYER))
echo "Salt: $SALT"

# We'll need to call the proxy factory to get the predicted address
# For now, we'll deploy the bonding curve after the proxy

# Step 8: Deploy SimpleBondingCurve (we'll use address(0) temporarily)
echo "=== Step 8: Deploying SimpleBondingCurve ==="
echo "Note: Using address(0) for launchpad temporarily. Will need to update later."
BONDING_CURVE_BYTECODE=$(forge inspect src/launchpad/BondingCurves/SimpleBondingCurve.sol:SimpleBondingCurve bytecode)
BONDING_CURVE_CONSTRUCTOR=$(cast abi-encode "constructor(address)" 0x0000000000000000000000000000000000000000)

echo "Deploying Bonding Curve..."
BONDING_CURVE_TX=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --create "${BONDING_CURVE_BYTECODE}${BONDING_CURVE_CONSTRUCTOR:2}" --legacy --gas-limit 10000000 --json)
BONDING_CURVE_ADDRESS=$(echo $BONDING_CURVE_TX | jq -r '.contractAddress')
echo "Bonding Curve deployed at: $BONDING_CURVE_ADDRESS"
echo ""

# Print summary
echo "=== Deployment Summary ==="
echo "Factory: $FACTORY_ADDRESS"
echo "Router: $ROUTER_ADDRESS"
echo "Distributor: $DISTRIBUTOR_ADDRESS"
echo "LP Vault: $LPVAULT_ADDRESS"
echo "Launchpad Implementation: $LAUNCHPAD_IMPL_ADDRESS"
echo "Proxy Factory: $PROXY_FACTORY_ADDRESS"
echo "Bonding Curve: $BONDING_CURVE_ADDRESS"
echo ""
echo "Next steps:"
echo "1. Deploy launchpad proxy using the proxy factory"
echo "2. Initialize the launchpad proxy"
echo "3. Update bonding curve with correct launchpad address"
echo ""
echo "Save these addresses!"
