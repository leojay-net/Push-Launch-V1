# Test Token Faucet

## Overview

The Test Token Faucet allows users to mint free test tokens on Push Chain Testnet for development and testing purposes.

## Features

- **6 Test Tokens Available**: Mint WETH, USDT, USDC, DAI, BSC, and WPUSH
- **1000 Tokens Per Mint**: Each mint gives you 1000 tokens
- **60 Second Cooldown**: Wait 1 minute between mints for the same token
- **Wallet Integration**: Seamlessly integrated with Push Chain wallet
- **Real-time Notifications**: Toast notifications for success/error feedback
- **Cooldown Timer**: Visual countdown showing when you can mint again

## How to Use

1. **Connect Wallet**: Click the "Connect Wallet" button in the header
2. **Navigate to Faucet**: Click "Faucet" in the navigation menu or visit `/faucet`
3. **Select Token**: Choose which test token you want to mint
4. **Mint Tokens**: Click the "Mint" button to receive 1000 tokens
5. **Wait for Cooldown**: Wait 60 seconds before minting the same token again
6. **Use Tokens**: Trade on DEX, add liquidity, or test the launchpad

## Available Test Tokens

| Token | Symbol | Decimals | Per Mint | Contract Address |
|-------|--------|----------|----------|------------------|
| Wrapped Ether | WETH | 18 | 1000 | 0x9e9eE7F2e34a61ADC7b9d40F5Cf02b1841dC8dA9 |
| Tether USD | USDT | 6 | 1000 | 0xf5065BA2DBF1Ec636531253449983f0EafebfD87 |
| USD Coin | USDC | 6 | 1000 | 0x8afc81487682024368AC225B799C3b325D82BEB4 |
| Dai Stablecoin | DAI | 18 | 1000 | 0x9395EcA683139b9Fe59D4E56dF4Eb132f0F2a103 |
| BSC Token | BSC | 18 | 1000 | 0xE6AEead4278FC9d7Ee83780F5378C30838B9a0bA |
| Wrapped PUSH | WPUSH | 18 | 1000 | 0x1e87a2194c31bFDE3999074e3EbB34d5c5830985 |

## Technical Details

### Transaction Flow

1. User clicks "Mint" button
2. Frontend encodes mint function call: `mint(address to, uint256 amount)`
3. Universal transaction sent via Push Chain client
4. Token contract mints tokens to user's address
5. Success notification displayed

### Smart Contract Requirements

Each token contract must have a public `mint` function:

```solidity
function mint(address to, uint256 amount) external;
```

### Cooldown Mechanism

- Implemented client-side using `localStorage` and timestamps
- Prevents spam and ensures fair distribution
- Can be bypassed by clearing browser storage (acceptable for testnet)

### Error Handling

- Wallet not connected
- Insufficient permissions
- Contract call failures
- Network errors
- Cooldown violations

## Use Cases

### 1. DEX Testing
Mint tokens to test swapping functionality:
```
1. Mint WETH and USDT
2. Go to DEX
3. Swap WETH for USDT
```

### 2. Liquidity Testing
Add liquidity to pools:
```
1. Mint two different tokens
2. Go to Liquidity page
3. Add liquidity to create a pool
```

### 3. Launchpad Testing
Test token launches:
```
1. Mint WETH (used as quote token)
2. Launch your own token
3. Buy tokens with WETH
```

### 4. Graduated Token Trading
Trade graduated tokens:
```
1. Mint WETH
2. Find graduated token in marketplace
3. Click "Trade on DEX"
4. Swap WETH for graduated token
```

## Security Notes

⚠️ **Testnet Only**: These are test tokens with no real value
⚠️ **Public Mint Function**: Anyone can mint these tokens
⚠️ **No Real Assets**: Do not use on mainnet

## Future Enhancements

- [ ] Multi-token mint (mint all tokens at once)
- [ ] Custom mint amounts
- [ ] Token approval helper
- [ ] Balance display before minting
- [ ] Transaction history
- [ ] Drip campaigns (daily limits)
- [ ] Faucet statistics (total minted, unique users)

## Troubleshooting

### "Wallet Not Connected"
- Click "Connect Wallet" in the header
- Ensure your wallet is unlocked

### "Cooldown Active"
- Wait for the countdown to finish
- Try minting a different token

### "Transaction Failed"
- Check you have enough native tokens for gas
- Verify the contract address is correct
- Check network connectivity

### Tokens Not Showing in Wallet
- Add the token contract address to your wallet manually
- Check if the transaction was successful on the explorer

## Contributing

To add a new test token to the faucet:

1. Deploy a mintable ERC20 contract
2. Add to `COMMON_TOKENS` in `src/lib/contracts.ts`
3. Token will automatically appear in the faucet
4. Update this README with token details

## Links

- [Push Chain Testnet Explorer](https://donut.push.network/)
- [Push Protocol Documentation](https://docs.push.org/)
- [GitHub Repository](https://github.com/pushprotocol)
