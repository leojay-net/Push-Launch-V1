// Push Chain Testnet Configuration
export const CHAIN_CONFIG = {
    chainId: 42101,
    name: "Push Chain Testnet",
    rpcUrl: "https://evm.rpc-testnet-donut-node1.push.org/",
    rpcUrlAlt: "https://evm.rpc-testnet-donut-node2.push.org/",
    explorer: "https://donut.push.network/",
    symbol: "PC",
    decimals: 18,
};

// Deployed Contract Addresses
export const CONTRACTS = {
    LAUNCHPAD: "0xf6825368cCD35540c28ABAb4A64e6d740Cc5CA8a", // Launchpad Proxy
    ROUTER: "0x133a3108B0e35d1B9D0F5E47A0f5F8ba153Ddb7F",
    FACTORY: "0xDAbc0d2Ee510885535451528F9C1cf24e2396580",
    BONDING_CURVE: "0xcb515e26503D8091Eee79Ad55a016C0338709507", // SimpleBondingCurve Proxy
    LP_VAULT: "0x3e0F9E341aa037b4a0144415FEB6Bbd0f8f836B0", // LaunchpadLPVault Proxy
    DISTRIBUTOR: "0x370d25b9bcef2E115113b0759AF2374Af10a446b",
    WETH: "0x9e9eE7F2e34a61ADC7b9d40F5Cf02b1841dC8dA9",
    ERC1967_FACTORY: "0xFDbd3E9b4018Aa044c35830804818BC93eC13c1B",
} as const;

// Common Token List (Add your tokens here)
export interface Token {
    address: string;
    symbol: string;
    name: string;
    decimals: number;
    logoURI?: string;
}

export const COMMON_TOKENS: Token[] = [
    {
        address: CONTRACTS.WETH,
        symbol: "WPUSH",
        name: "Wrapped PUSH",
        decimals: 18,
        logoURI: "/tokens/wpush.png",
    },
    {
        address: "0xf5065BA2DBF1Ec636531253449983f0EafebfD87",
        symbol: "USDT",
        name: "Tether USD",
        decimals: 6,
        logoURI: "/tokens/usdt.png",
    },
    {
        address: "0x8afc81487682024368AC225B799C3b325D82BEB4",
        symbol: "USDC",
        name: "USD Coin",
        decimals: 6,
        logoURI: "/tokens/usdc.png",
    },
    {
        address: "0x9395EcA683139b9Fe59D4E56dF4Eb132f0F2a103",
        symbol: "DAI",
        name: "Dai Stablecoin",
        decimals: 18,
        logoURI: "/tokens/dai.png",
    },
    {
        address: "0xE6AEead4278FC9d7Ee83780F5378C30838B9a0bA",
        symbol: "BSC",
        name: "BSC Token",
        decimals: 18,
        logoURI: "/tokens/bsc.png",
    },
    // Add more tokens as they launch
];

// Bonding Curve Configuration
export const BONDING_CURVE_CONFIG = {
    VIRTUAL_BASE: "200000000", // 200M tokens
    VIRTUAL_QUOTE: "10", // 10 WPUSH
    BONDING_SUPPLY: "800000000", // 800M tokens
    TOTAL_SUPPLY: "1000000000", // 1B tokens
};

// Transaction Settings
export const TX_SETTINGS = {
    DEFAULT_SLIPPAGE: 0.5, // 0.5%
    MAX_SLIPPAGE: 50, // 50%
    DEFAULT_DEADLINE: 20, // 20 minutes
};

// Feature Flags for Token Launch
export const FEATURE_FLAGS = {
    REWARDS_ENABLED: 1 << 0, // Bit 0
    UNIVERSAL_ENABLED: 1 << 1, // Bit 1
    // Add more flags as needed
};

export const getFeatureFlags = (
    rewards: boolean = true,
    universal: boolean = true
): number => {
    let flags = 0;
    if (rewards) flags |= FEATURE_FLAGS.REWARDS_ENABLED;
    if (universal) flags |= FEATURE_FLAGS.UNIVERSAL_ENABLED;
    return flags;
};
