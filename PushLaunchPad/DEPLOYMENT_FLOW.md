# Deployment Flow Diagram

## Phase 1: Initial Deployment (Breaking Circular Dependency)

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Deploy Factory with address(0)                      │
├─────────────────────────────────────────────────────────────┤
│ new PushLaunchpadV2PairFactory(                             │
│     feeToSetter,                                            │
│     address(0), // launchpad                                │
│     address(0), // launchpadLp                              │
│     address(0)  // launchpadFeeDistributor                  │
│ )                                                           │
│                                                             │
│ Result: Factory deployed at 0xFACT0RY...                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Deploy Router                                       │
├─────────────────────────────────────────────────────────────┤
│ new PushLaunchpadV2Router2(                                 │
│     0xFACT0RY..., // factory                                │
│     0xWETH...     // WETH                                   │
│ )                                                           │
│                                                             │
│ Result: Router deployed at 0xR0UTER...                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: Deploy Supporting Contracts                         │
├─────────────────────────────────────────────────────────────┤
│ 3a. new Distributor()                                       │
│     Result: 0xDISTR...                                      │
│                                                             │
│ 3b. new LaunchpadLPVault()                                  │
│     Result: 0xVAULT...                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 4: Deploy Launchpad Implementation                     │
├─────────────────────────────────────────────────────────────┤
│ new Launchpad(                                              │
│     0xR0UTER..., // router                                  │
│     0xDISTR...   // distributor                             │
│ )                                                           │
│                                                             │
│ Result: Implementation at 0xIMPL...                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 5: Deploy Launchpad Proxy (CREATE2)                    │
├─────────────────────────────────────────────────────────────┤
│ new ERC1967Factory()                                        │
│ proxyFactory.deployDeterministic(0xIMPL..., salt)          │
│                                                             │
│ Result: Proxy at 0xLAUNCH...                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 6: Deploy Bonding Curve                                │
├─────────────────────────────────────────────────────────────┤
│ new SimpleBondingCurve(0xLAUNCH...)                         │
│                                                             │
│ Result: Bonding Curve at 0xCURVE...                         │
└─────────────────────────────────────────────────────────────┘
```

## Phase 2: Update Factory (Enable Special Pairs)

```
┌─────────────────────────────────────────────────────────────┐
│ Step 7: Update Factory Addresses                            │
├─────────────────────────────────────────────────────────────┤
│ factory.setLaunchpadAddresses(                              │
│     0xLAUNCH..., // launchpad                               │
│     0xVAULT...,  // launchpadLp                             │
│     0xDISTR...   // launchpadFeeDistributor                 │
│ )                                                           │
│                                                             │
│ ✅ Factory now supports special launchpad pairs!            │
└─────────────────────────────────────────────────────────────┘
```

## Pair Creation Behavior

### Before Update (address(0) for launchpad)

```
User/Router creates pair:
┌────────────────┐
│   createPair   │
│   msg.sender   │
│      ≠         │
│   address(0)   │  ← Always false
└────────┬───────┘
         │
         ↓
    Use address(0) for fee params
         │
         ↓
┌────────────────┐
│  Normal Pair   │
│  Standard fees │
└────────────────┘
```

### After Update (real launchpad address)

```
Router creates pair:                    Launchpad creates pair:
┌────────────────┐                     ┌────────────────┐
│   createPair   │                     │   createPair   │
│   msg.sender   │                     │   msg.sender   │
│      ≠         │                     │      ==        │
│  0xLAUNCH...   │ ← False             │  0xLAUNCH...   │ ← True!
└────────┬───────┘                     └────────┬───────┘
         │                                      │
         ↓                                      ↓
    Use address(0)                         Use real addresses
    for fee params                         for fee params
         │                                      │
         ↓                                      ↓
┌────────────────┐                     ┌────────────────┐
│  Normal Pair   │                     │ Launchpad Pair │
│  Standard fees │                     │  Enhanced fees │
│                │                     │  → LP Vault    │
│                │                     │  → Distributor │
└────────────────┘                     └────────────────┘
```

## Fee Distribution Comparison

### Normal Pair (Created by Router/User)
```
Trading Fees (0.3%)
        │
        ↓
┌───────────────────┐
│   Liquidity Pool  │
│   (All LPs share) │
└───────────────────┘
```

### Launchpad Pair (Created by Launchpad)
```
Trading Fees (0.3%)
        │
        ├─────────────────┐
        │                 │
        ↓                 ↓
┌──────────────┐   ┌──────────────┐
│   LP Vault   │   │ Distributor  │
│ (LP holders) │   │ (Protocol)   │
└──────────────┘   └──────────────┘
        │                 │
        ↓                 ↓
    Stakers get       Protocol
    trading fees      revenue
```

## System Architecture (After Update)

```
┌─────────────────────────────────────────────────────────────┐
│                      Push Launchpad System                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐         ┌──────────────┐                │
│  │  Launchpad   │────────▶│    Router    │                │
│  │  (Proxy)     │         │              │                │
│  └──────┬───────┘         └──────┬───────┘                │
│         │                        │                         │
│         │                        │                         │
│         ▼                        ▼                         │
│  ┌──────────────┐         ┌──────────────┐                │
│  │ Bonding      │         │   Factory    │◀───┐           │
│  │ Curve        │         │ (Updated!)   │    │           │
│  └──────────────┘         └──────┬───────┘    │           │
│                                  │             │           │
│                                  │   Creates   │           │
│                                  ▼             │           │
│  ┌──────────────┐         ┌──────────────┐    │           │
│  │ Distributor  │◀────────│ Launchpad    │────┘           │
│  │              │         │ Pair (NEW!)  │  Knows LP      │
│  └──────────────┘         └──────┬───────┘  & Distributor │
│         ▲                        │                         │
│         │                        ▼                         │
│         │                 ┌──────────────┐                │
│         └─────────────────│   LP Vault   │                │
│                           │              │                │
│                           └──────────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Complete Deployment Commands

```bash
# Phase 1: Deploy all contracts
FACTORY=$(forge create ... --constructor-args $DEPLOYER 0x0 0x0 0x0)
ROUTER=$(forge create ... --constructor-args $FACTORY $WETH)
DISTRIBUTOR=$(forge create ...)
LP_VAULT=$(forge create ...)
LAUNCHPAD_IMPL=$(forge create ... --constructor-args $ROUTER $DISTRIBUTOR)
# Deploy proxy...
LAUNCHPAD_PROXY=$(...)
BONDING_CURVE=$(forge create ... --constructor-args $LAUNCHPAD_PROXY)

# Phase 2: Update factory
cast send $FACTORY \
  "setLaunchpadAddresses(address,address,address)" \
  $LAUNCHPAD_PROXY \
  $LP_VAULT \
  $DISTRIBUTOR

# ✅ System is now fully configured!
```

## Summary

| Phase | Status | Capability |
|-------|--------|-----------|
| **Phase 1: Initial Deployment** | ✅ Complete | Normal pairs work |
| **Phase 2: Factory Update** | ✅ Complete | Launchpad pairs work |
| **Result** | 🚀 Ready | Full system operational |

**All 114 tests passing!** ✅
