# Graduated Tokens Integration - DEX Visibility

## Overview

This document describes the implementation that makes graduated tokens discoverable and tradeable in the DEX interface.

## Problem Statement

When tokens graduate from the launchpad:
1. They automatically get a WETH pair created on the DEX
2. However, users couldn't find these tokens in the token selector
3. There was no clear path from the marketplace to trading on the DEX

## Solution Components

### 1. **Auto-Discovery of Graduated Tokens**

**File**: `src/components/dex/TokenSelector.tsx`

**Changes**:
- Integrated `useLaunchHistory` hook to fetch all launched tokens
- Filter tokens with `status === "completed"` (graduated)
- Automatically add graduated tokens to the token list alongside `COMMON_TOKENS`
- Display "Graduated" badge on graduated tokens in the selector

```typescript
// Get graduated tokens from marketplace
const graduatedTokens = launches
    .filter(launch => launch.status === "completed")
    .map(launch => ({
        address: launch.token,
        symbol: launch.symbol,
        name: launch.name,
        decimals: 18,
        isGraduated: true
    }));

// Combine common tokens with graduated tokens
const allTokens = [
    ...COMMON_TOKENS,
    ...graduatedTokens.filter(gt => 
        !COMMON_TOKENS.some(ct => ct.address.toLowerCase() === gt.address.toLowerCase())
    )
];
```

### 2. **Custom Token Import Feature**

**File**: `src/components/dex/TokenSelector.tsx`

**Features**:
- Users can import ANY ERC20 token by pasting its contract address
- Automatically fetches token metadata (name, symbol, decimals) from the blockchain
- Shows token preview before confirming import
- Includes security warning about verifying token authenticity
- Two-modal flow: Import → Preview & Confirm

**UI Flow**:
1. User clicks "Import custom token" at bottom of token selector
2. Enters token contract address (0x...)
3. System fetches token details from blockchain
4. Shows preview with name, symbol, decimals, and warning
5. User confirms to import and trade

### 3. **Direct DEX Links from Marketplace**

**Files**: 
- `src/components/marketplace/TokenCard.tsx`
- `src/app/token/[address]/page.tsx`

**Changes**:
- Added "Trade DEX" button on graduated token cards in marketplace
- Added "Trade on DEX" link in token detail page header (only for graduated tokens)
- Links navigate to `/dex?token=<address>`

**Example**:
```tsx
{status === "completed" && (
    <Link
        href={`/dex?token=${token}`}
        className="flex items-center gap-1 font-medium text-emerald-600"
    >
        Trade DEX
        <ExternalLink className="w-3 h-3" />
    </Link>
)}
```

### 4. **Pre-Selection via URL Parameters**

**Files**:
- `src/app/dex/page.tsx`
- `src/components/dex/SwapInterface.tsx`

**Changes**:
- DEX page reads `?token=<address>` from URL query params
- Automatically sets the graduated token as the "To" token
- Sets WETH as the "From" token (since graduated tokens always have WETH pairs)
- Shows confirmation message: "Trading graduated token 0x1234..."

**Implementation**:
```typescript
// In SwapInterface
useEffect(() => {
    if (preSelectedToken && ethers.isAddress(preSelectedToken)) {
        const graduatedToken = launches.find(
            l => l.status === "completed" && 
            l.token.toLowerCase() === preSelectedToken.toLowerCase()
        );
        
        if (graduatedToken) {
            setToToken({
                address: graduatedToken.token,
                symbol: graduatedToken.symbol,
                name: graduatedToken.name,
                decimals: 18,
            });
            const weth = COMMON_TOKENS.find(t => t.symbol === "WETH");
            if (weth) setFromToken(weth);
        }
    }
}, [preSelectedToken, launches]);
```

## User Flows

### Flow 1: Trade Graduated Token from Marketplace

1. User browses marketplace and sees token with "Graduated" badge
2. Clicks "Trade DEX" button on token card
3. Redirected to `/dex?token=0x...`
4. DEX opens with WETH → GraduatedToken pair pre-selected
5. User enters amount and completes swap

### Flow 2: Find Graduated Token in Token Selector

1. User goes to DEX
2. Clicks "Select Token" button
3. Sees all graduated tokens listed with "Graduated" badge
4. Can search by name, symbol, or address
5. Selects token and trades

### Flow 3: Import Any Custom Token

1. User goes to DEX token selector
2. Clicks "Import custom token" at bottom
3. Pastes token contract address
4. Reviews token details and security warning
5. Confirms import
6. Token is added to swap interface

## Technical Details

### Token List Priority

1. **COMMON_TOKENS**: Pre-defined tokens (WETH, USDT, USDC, DAI, etc.)
2. **Graduated Tokens**: Auto-fetched from launchpad contract events
3. **Custom Imports**: User-added tokens (stored in component state)

### Balance Fetching

All tokens (common + graduated + custom) have their balances fetched when the token selector opens:

```typescript
const entries = await Promise.all(
    allTokens.map(async (token) => {
        const balance = await getTokenBalance(token);
        return [token.address, balance.formatted] as const;
    })
);
```

### Pair Validation

When `requireExistingPair` flag is true (e.g., in Add Liquidity), the system:
- Checks each token against the selected pair token
- Uses `getPairInfo(tokenA, tokenB)` to verify pool exists
- Filters out tokens without existing pairs
- Shows loading state: "Checking available pairs..."

### Security Considerations

**Custom Token Import Warning**:
```
⚠️ Be careful!
Anyone can create a token with any name. Make sure this is the 
correct token before trading.
```

This warning is shown because:
- Malicious actors can create tokens with identical names to legitimate ones
- Users must verify the contract address matches official sources
- ERC20 tokens can be created by anyone with any name/symbol

## Testing Checklist

- [ ] Graduated tokens appear in token selector with badge
- [ ] "Trade DEX" button visible on graduated token cards
- [ ] Clicking "Trade DEX" navigates to DEX with token pre-selected
- [ ] Custom token import fetches metadata correctly
- [ ] Custom token import shows error for invalid addresses
- [ ] Token balances fetch for all token types
- [ ] Pair validation works for graduated tokens
- [ ] Pre-selection via URL works correctly
- [ ] Search works for graduated tokens by name, symbol, address

## Future Enhancements

1. **LocalStorage Persistence**: Save custom imported tokens to browser storage
2. **Token Metadata Caching**: Cache fetched token details to avoid repeated RPC calls
3. **Token Lists**: Support importing token lists (e.g., CoinGecko, Uniswap lists)
4. **Token Logo Service**: Integrate with logo services (Trust Wallet, Token Lists)
5. **Advanced Filtering**: Filter by trading volume, liquidity, price change
6. **Favorites**: Allow users to favorite/pin frequently used tokens

## Dependencies

- **ethers.js**: For address validation and contract interactions
- **@pushchain/ui-kit**: For Push Chain client and wallet integration
- **useLaunchHistory**: Hook to fetch launched tokens from contract
- **useDexRouter**: Hook for DEX operations (swap, liquidity, balances)

## Performance Considerations

- Token list is filtered client-side for fast search
- Balance fetching uses `Promise.all` for parallel requests
- Pair validation has loading state to indicate async operation
- Component uses `useEffect` cleanup to prevent memory leaks
- Large token lists are rendered in scrollable container with max-height

## Conclusion

Graduated tokens are now fully integrated into the DEX with:
✅ Auto-discovery and visibility
✅ Direct links from marketplace
✅ Custom token import capability
✅ Pre-selection via URL parameters
✅ Clear visual indicators (badges)
✅ Security warnings for custom imports

Users can seamlessly transition from launching tokens to trading them on the DEX.
