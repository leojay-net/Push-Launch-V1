"use client";

import { useEffect, useState } from "react";
import { Search, X } from "lucide-react";
import Modal from "../ui/Modal";
import Input from "../ui/Input";
import { COMMON_TOKENS, type Token } from "@/lib/contracts";
import { formatNumber } from "@/lib/utils";
import { useDexRouter } from "@/hooks/useDexRouter";

interface TokenSelectorProps {
    isOpen: boolean;
    onClose: () => void;
    onSelect: (token: Token) => void;
    excludeToken?: Token | null;
    pairWith?: Token | null;
    requireExistingPair?: boolean;
}

export default function TokenSelector({
    isOpen,
    onClose,
    onSelect,
    excludeToken,
    pairWith,
    requireExistingPair = false,
}: TokenSelectorProps) {
    const [searchQuery, setSearchQuery] = useState("");
    const [balances, setBalances] = useState<Record<string, string>>({});
    const { getTokenBalance, isWalletConnected, getPairInfo } = useDexRouter();
    const [allowedPairs, setAllowedPairs] = useState<Set<string> | null>(null);
    const [checkingPairs, setCheckingPairs] = useState(false);

    useEffect(() => {
        let cancelled = false;

        const fetchBalances = async () => {
            if (!isOpen || !isWalletConnected) {
                if (!cancelled) {
                    setBalances({});
                }
                return;
            }

            try {
                const entries = await Promise.all(
                    COMMON_TOKENS.map(async (token) => {
                        const balance = await getTokenBalance(token);
                        return [token.address, balance.formatted] as const;
                    })
                );

                if (!cancelled) {
                    setBalances(Object.fromEntries(entries));
                }
            } catch (err) {
                console.error("Failed to load token balances", err);
            }
        };

        fetchBalances();

        return () => {
            cancelled = true;
        };
    }, [isOpen, isWalletConnected, getTokenBalance]);

    // Compute which tokens have an existing pair with the provided token
    useEffect(() => {
        let cancelled = false;
        const run = async () => {
            if (!isOpen || !requireExistingPair || !pairWith) {
                setAllowedPairs(null);
                setCheckingPairs(false);
                return;
            }
            setCheckingPairs(true);
            try {
                const entries = await Promise.all(
                    COMMON_TOKENS.map(async (token) => {
                        if (excludeToken && token.address === excludeToken.address) {
                            return [token.address, false] as const;
                        }
                        if (token.address.toLowerCase() === pairWith.address.toLowerCase()) {
                            return [token.address, false] as const;
                        }
                        try {
                            const info = await getPairInfo(pairWith, token);
                            return [token.address, info.exists] as const;
                        } catch {
                            return [token.address, false] as const;
                        }
                    })
                );
                if (!cancelled) {
                    setAllowedPairs(
                        new Set(entries.filter(([, ok]) => ok).map(([addr]) => addr))
                    );
                }
            } finally {
                if (!cancelled) setCheckingPairs(false);
            }
        };
        run();
        return () => {
            cancelled = true;
        };
    }, [isOpen, requireExistingPair, pairWith, excludeToken, getPairInfo]);

    // Filter tokens based on search and exclusion
    const filteredTokens = COMMON_TOKENS.filter((token) => {
        const matchesSearch =
            token.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
            token.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
            token.address.toLowerCase().includes(searchQuery.toLowerCase());

        const isNotExcluded = !excludeToken || token.address !== excludeToken.address;

        const hasPair = !requireExistingPair || !pairWith
            ? true
            : !!allowedPairs && allowedPairs.has(token.address);

        return matchesSearch && isNotExcluded && hasPair;
    });

    const handleSelect = (token: Token) => {
        onSelect(token);
        setSearchQuery("");
    };

    return (
        <Modal
            isOpen={isOpen}
            onClose={onClose}
            title="Select a Token"
            description="Search by name, symbol, or address"
            size="md"
        >
            <div className="space-y-4">
                {/* Search Input */}
                <Input
                    placeholder="Search tokens..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    leftIcon={<Search className="w-4 h-4" />}
                    rightElement={
                        searchQuery && (
                            <button
                                onClick={() => setSearchQuery("")}
                                className="p-1 hover:bg-gray-100 rounded"
                            >
                                <X className="w-4 h-4 text-gray-400" />
                            </button>
                        )
                    }
                />

                {/* Token List */}
                <div className="max-h-[400px] overflow-y-auto">
                    {requireExistingPair && pairWith && checkingPairs && (
                        <div className="text-center py-6 text-gray-500">Checking available pairs…</div>
                    )}
                    {filteredTokens.length === 0 ? (
                        <div className="text-center py-8 text-gray-500">
                            <p>No tokens found</p>
                            <p className="text-sm mt-1">Try a different search</p>
                        </div>
                    ) : (
                        <div className="space-y-1">
                            {filteredTokens.map((token) => (
                                <button
                                    key={token.address}
                                    onClick={() => handleSelect(token)}
                                    className="w-full flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg transition-colors text-left"
                                >
                                    {/* Token Logo Placeholder */}
                                    <div className="w-10 h-10 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-white font-bold text-sm">
                                        {token.symbol.substring(0, 2)}
                                    </div>

                                    {/* Token Info */}
                                    <div className="flex-1">
                                        <div className="font-medium text-gray-900">{token.symbol}</div>
                                        <div className="text-sm text-gray-500">{token.name}</div>
                                    </div>

                                    {/* Balance (TODO: Fetch actual balance) */}
                                    <div className="text-right">
                                        <div className="font-medium text-gray-900">
                                            {formatNumber(balances[token.address] ?? "0", 4)}
                                        </div>
                                    </div>
                                </button>
                            ))}
                        </div>
                    )}
                </div>

                {/* Add Custom Token Notice */}
                <div className="pt-4 border-t border-gray-200">
                    <p className="text-sm text-gray-600 text-center">
                        Don&apos;t see your token?{" "}
                        <button className="text-emerald-600 hover:text-emerald-700 font-medium">
                            Import custom token
                        </button>
                    </p>
                </div>
            </div>
        </Modal>
    );
}
