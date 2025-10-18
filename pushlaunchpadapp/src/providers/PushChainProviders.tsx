"use client";

import {
    PushUI,
    PushUniversalWalletProvider,
    type AppMetadata,
    type ProviderConfigProps,
} from "@pushchain/ui-kit";

export const PushChainProviders = ({ children }: { children: React.ReactNode }) => {
    const walletConfig: ProviderConfigProps = {
        network: PushUI.CONSTANTS.PUSH_NETWORK.TESTNET,
        // Attempt to restore the last connected session on reload
        // (supported by runtime even if not present in the TS types)
        // Injected via index access to avoid TS complaints
        ...({ autoConnect: true } as Record<string, unknown>),

        login: {
            email: true,
            google: true,
            wallet: {
                enabled: true,
            },
            appPreview: true,
        },

        modal: {
            loginLayout: PushUI.CONSTANTS.LOGIN.LAYOUT.SPLIT,
            connectedLayout: PushUI.CONSTANTS.CONNECTED.LAYOUT.HOVER,
            appPreview: true,
            connectedInteraction: PushUI.CONSTANTS.CONNECTED.INTERACTION.BLUR,
        },

        chainConfig: {
            rpcUrls: {
                // Ethereum Sepolia testnet
                "eip155:11155111": ["https://sepolia.gateway.tenderly.co/"],
            },
        },
    } as ProviderConfigProps;

    const appMetadata: AppMetadata = {
        logoUrl: "https://avatars.githubusercontent.com/u/64157541?v=4",
        title: "Push Chain Launchpad",
        description:
            "Launch tokens and provide liquidity on Push Chain - the universal blockchain enabling cross-chain interactions without bridges.",
    };

    return (
        <PushUniversalWalletProvider config={walletConfig} app={appMetadata}>
            {children}
        </PushUniversalWalletProvider>
    );
};
