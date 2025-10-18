# Push Chain Launchpad - Modern Frontend Implementation Guide

## 🎨 Design System

### Color Palette
- Primary: `#22C55E` (Emerald 500) - Actions, CTAs
- Secondary: `#6366F1` (Indigo 500) - Highlights
- Success: `#10B981` (Emerald 600)
- Warning: `#F59E0B` (Amber 500)
- Error: `#EF4444` (Red 500)
- Background: `#F9FAFB` (Gray 50)
- Surface: `#FFFFFF`
- Text Primary: `#111827` (Gray 900)
- Text Secondary: `#6B7280` (Gray 500)

### Typography
- Headings: Inter (600-700 weight)
- Body: Inter (400-500 weight)
- Mono: Geist Mono (for addresses, numbers)

### Shadows
- Card: `0 1px 3px 0 rgb(0 0 0 / 0.1)`
- Hover: `0 4px 6px -1px rgb(0 0 0 / 0.1)`
- Active: `0 10px 15px -3px rgb(0 0 0 / 0.1)`

## 🏗️ Project Structure

```
src/
├── app/
│   ├── layout.tsx                 # Root layout with providers
│   ├── page.tsx                   # Home/DEX page
│   ├── launch/page.tsx            # Launchpad page
│   └── globals.css                # Global styles
├── components/
│   ├── layout/
│   │   ├── Header.tsx             # Top navigation + wallet
│   │   ├── Sidebar.tsx            # Side navigation
│   │   └── Layout.tsx             # Main layout wrapper
│   ├── dex/
│   │   ├── SwapInterface.tsx      # Main swap UI
│   │   ├── TokenSelector.tsx      # Token selection modal
│   │   ├── PriceImpact.tsx        # Price impact display
│   │   └── SlippageSettings.tsx   # Slippage configuration
│   ├── launchpad/
│   │   ├── LaunchForm.tsx         # Token launch form
│   │   ├── BondingCurveChart.tsx  # Curve visualization
│   │   ├── LaunchList.tsx         # Recent launches
│   │   └── LaunchDetails.tsx      # Individual launch info
│   ├── ui/
│   │   ├── Button.tsx             # Styled button component
│   │   ├── Card.tsx               # Card container
│   │   ├── Input.tsx              # Input field
│   │   ├── Modal.tsx              # Modal component
│   │   └── Badge.tsx              # Status badges
│   └── shared/
│       ├── TransactionStatus.tsx  # TX status indicator
│       ├── LoadingSpinner.tsx     # Loading states
│       └── ErrorBoundary.tsx      # Error handling
├── lib/
│   ├── contracts.ts               # Contract addresses & ABIs
│   ├── utils.ts                   # Utility functions
│   └── cn.ts                      # Class name utilities
├── hooks/
│   ├── useDEX.ts                  # DEX operations hook
│   ├── useLaunchpad.ts            # Launchpad operations hook
│   └── useContract.ts             # Contract interaction hook
└── providers/
    └── PushChainProviders.tsx     # Push Chain wallet provider
```

## 📦 Deployed Contracts (Push Chain Testnet)

```typescript
// lib/contracts.ts
export const CONTRACTS = {
  LAUNCHPAD: "0x6183dC0D418E83a8413c626E167Ec3Ffaac92EF1",
  ROUTER: "0x4CD41Ae6e61a66Ed04E301147E2Fa30215EfCa30",
  FACTORY: "0x77BEC78cC653Edc766456C6fA855248c546507b0",
  BONDING_CURVE: "0x0c87b025Ad9572CE256bE0143Babae6e2aE4B7c9",
  LP_VAULT: "0x347AE14187aE39208c6158b44A1e6330b182E522",
  DISTRIBUTOR: "0xE968E223C742D785CE45b0661c4913b91c9Bc907",
  WETH: "0x0d0dF7E8807430A81104EA84d926139816eC7586",
};

export const CHAIN_CONFIG = {
  chainId: 42101,
  rpcUrl: "https://evm.rpc-testnet-donut-node1.push.org/",
  explorer: "https://donut.push.network/",
};
```

## 🎭 Component Examples

### 1. Swap Interface

**Features:**
- Token selection with search
- Amount input with max button
- Price display with inversion toggle
- Slippage settings
- Price impact warning
- Transaction preview
- Universal transaction via Push Chain

**Animations:**
- Fade in on mount
- Slide up for modals
- Pulse for loading states
- Smooth transitions for all interactions

### 2. Launchpad Interface

**Features:**
- Token parameter form (name, symbol, supply)
- Bonding curve visualization (interactive chart)
- Real-time pricing preview
- Launch fee display
- Transaction status tracking
- Success celebration animation

**Animations:**
- Step-by-step form progression
- Chart animation on curve adjustment
- Confetti on successful launch
- Smooth scroll to results

## 🎬 Animation Patterns

### Framer Motion Variants

```typescript
// Fade in from bottom
const fadeInUp = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -20 },
  transition: { duration: 0.3 }
};

// Scale in
const scaleIn = {
  initial: { opacity: 0, scale: 0.9 },
  animate: { opacity: 1, scale: 1 },
  exit: { opacity: 0, scale: 0.9 },
  transition: { duration: 0.2 }
};

// Slide from right
const slideFromRight = {
  initial: { x: "100%" },
  animate: { x: 0 },
  exit: { x: "100%" },
  transition: { type: "spring", damping: 20 }
};
```

## 🔌 Push Chain Integration

### Universal Transaction Pattern

```typescript
import { usePushChainClient, usePushChain } from "@pushchain/ui-kit";

const { pushChainClient } = usePushChainClient();
const { PushChain } = usePushChain();

// Swap tokens
const handleSwap = async () => {
  const tx = await pushChainClient.universal.sendTransaction({
    to: CONTRACTS.ROUTER,
    data: PushChain.utils.helpers.encodeTxData({
      abi: RouterABI,
      functionName: "swapExactTokensForTokens",
      args: [amountIn, amountOutMin, path, to, deadline],
    }),
    value: BigInt(0),
  });
  
  await tx.wait();
};

// Launch token
const handleLaunch = async () => {
  const tx = await pushChainClient.universal.sendTransaction({
    to: CONTRACTS.LAUNCHPAD,
    data: PushChain.utils.helpers.encodeTxData({
      abi: LaunchpadABI,
      functionName: "launchToken",
      args: [name, symbol, tokenURI, featureFlags],
    }),
    value: launchFee,
  });
  
  await tx.wait();
};
```

## 🎨 UI Component Library

### Icons (lucide-react)
- ArrowLeftRight: Swap
- Rocket: Launch
- TrendingUp: Chart
- Settings: Settings
- Wallet: Wallet
- Check: Success
- AlertCircle: Warning
- Info: Information

### Animations (framer-motion)
- Layout animations for smooth transitions
- Gesture animations for interactions
- Exit animations for modals
- Stagger children for lists

## 📱 Responsive Design

- Desktop: Sidebar + content (1280px+)
- Tablet: Collapsed sidebar (768px - 1279px)
- Mobile: Bottom navigation (< 768px)

## 🚀 Next Steps

1. **Install remaining dependencies** (done)
2. **Create UI component library** (Button, Card, Input, etc.)
3. **Build layout components** (Header, Sidebar, Layout)
4. **Implement DEX interface** with swap functionality
5. **Implement Launchpad interface** with token creation
6. **Add contract ABIs** from deployment
7. **Test universal transactions** from different chains
8. **Polish animations and interactions**

## 📚 Key Resources

- Push Chain UI Kit Docs: https://docs.push.org/ui-kit
- Deployed Contracts: See `/PushLaunchPadHH/deployments/`
- ABIs: Export from Hardhat artifacts
- Icons: https://lucide.dev/
- Animations: https://www.framer.com/motion/

---

Would you like me to continue with the complete implementation? I can create:
1. All UI components (Button, Card, Input, etc.)
2. Complete DEX interface with swap functionality
3. Complete Launchpad interface with token creation
4. All the contract ABIs and integration code
5. Animations and transitions throughout

Let me know which parts you'd like me to build first!
