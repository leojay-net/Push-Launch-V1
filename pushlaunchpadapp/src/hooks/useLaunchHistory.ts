"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ethers, type EventLog } from "ethers";
import { LaunchpadABI } from "@/abis";
import { CHAIN_CONFIG, CONTRACTS } from "@/lib/contracts";

const rpcProvider = new ethers.JsonRpcProvider(CHAIN_CONFIG.rpcUrl);

const launchpadReadContract = new ethers.Contract(
    CONTRACTS.LAUNCHPAD,
    LaunchpadABI,
    rpcProvider
);

const launchTokenAbi = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function mediaURI() view returns (string)",
];

const parseNumericEnv = (value: string | undefined, fallback: number) => {
    if (!value) return fallback;

    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
};

const DEFAULT_START_BLOCK = parseNumericEnv(
    process.env.NEXT_PUBLIC_LAUNCHPAD_START_BLOCK,
    0
);

const LOOKBACK_BLOCKS = parseNumericEnv(
    process.env.NEXT_PUBLIC_LAUNCHPAD_LOOKBACK_BLOCKS,
    9000
);

const LOG_BATCH_SIZE = Math.max(
    1000,
    Math.min(
        parseNumericEnv(process.env.NEXT_PUBLIC_LAUNCHPAD_LOG_BATCH, 5000),
        9500
    )
);

interface LaunchData {
    token: string;
    name: string;
    symbol: string;
    mediaURI?: string;
    dev: string;
    quoteAsset: string;
    timestamp: number;
    blockNumber: number;
    raised: bigint;
    raisedFormatted: string;
    baseSold: bigint;
    progress: number;
    status: "active" | "completed";
}

interface UseLaunchHistoryResult {
    launches: LaunchData[];
    loading: boolean;
    error: string | null;
    refresh: () => Promise<void>;
}

const EMPTY_LAUNCHES: LaunchData[] = [];

export function useLaunchHistory(): UseLaunchHistoryResult {
    const [launches, setLaunches] = useState<LaunchData[]>(EMPTY_LAUNCHES);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);

    const fetchLaunches = useCallback(async () => {
        setLoading(true);
        setError(null);

        try {
            const bondingSupply: bigint = await launchpadReadContract.BONDING_SUPPLY();
            const filter = launchpadReadContract.filters.TokenLaunched?.();

            if (!filter) {
                throw new Error("TokenLaunched event filter unavailable");
            }

            const latestBlock = await rpcProvider.getBlockNumber();
            const startBlock = DEFAULT_START_BLOCK
                ? Math.max(0, DEFAULT_START_BLOCK)
                : Math.max(0, latestBlock - LOOKBACK_BLOCKS);

            const events: EventLog[] = [];
            let fromBlock = startBlock;

            while (fromBlock <= latestBlock) {
                const toBlock = Math.min(
                    fromBlock + LOG_BATCH_SIZE - 1,
                    latestBlock
                );

                const chunk = (await launchpadReadContract.queryFilter(
                    filter,
                    fromBlock,
                    toBlock
                )) as EventLog[];

                if (chunk.length) {
                    events.push(...chunk);
                }

                if (toBlock >= latestBlock) {
                    break;
                }

                fromBlock = toBlock + 1;
            }

            if (!events.length) {
                setLaunches(EMPTY_LAUNCHES);
                return;
            }

            const parsed = await Promise.all(
                events.map(async (event): Promise<LaunchData | null> => {
                    try {
                        const args = event.args as unknown as {
                            dev: string;
                            token: string;
                            quoteAsset: string;
                            bondingCurve: string;
                            timestamp: bigint;
                        };

                        const launchTokenContract = new ethers.Contract(
                            args.token,
                            launchTokenAbi,
                            rpcProvider
                        );

                        const [name, symbol, mediaURI, quoteRaised, baseSold, launchMeta] =
                            await Promise.all([
                                launchTokenContract.name(),
                                launchTokenContract.symbol(),
                                launchTokenContract.mediaURI().catch(() => ""),
                                launchpadReadContract.quoteBoughtByCurve(args.token),
                                launchpadReadContract.baseSoldFromCurve(args.token),
                                launchpadReadContract.launches(args.token),
                            ]);

                        const raisedFormatted = ethers.formatUnits(
                            quoteRaised,
                            CHAIN_CONFIG.decimals
                        );

                        const progress = bondingSupply
                            ? Number((baseSold * BigInt(10000)) / bondingSupply) / 100
                            : 0;

                        const summary: LaunchData = {
                            token: args.token,
                            name,
                            symbol,
                            mediaURI: mediaURI || undefined,
                            dev: args.dev,
                            quoteAsset: args.quoteAsset,
                            timestamp: Number(args.timestamp),
                            blockNumber: event.blockNumber ?? 0,
                            raised: quoteRaised,
                            raisedFormatted,
                            baseSold,
                            progress: progress > 100 ? 100 : progress,
                            status: launchMeta.active ? "active" : "completed",
                        };

                        return summary;
                    } catch (innerError) {
                        console.error("Failed to parse launch event", innerError);
                        return null;
                    }
                })
            );

            const cleaned = (parsed.filter(Boolean) as LaunchData[]).sort(
                (a, b) => b.timestamp - a.timestamp
            );

            setLaunches(cleaned);
        } catch (err) {
            console.error("Failed to fetch launch history", err);
            setError((err as Error).message);
            setLaunches(EMPTY_LAUNCHES);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchLaunches();
    }, [fetchLaunches]);

    const memoizedLaunches = useMemo(() => launches, [launches]);

    return {
        launches: memoizedLaunches,
        loading,
        error,
        refresh: fetchLaunches,
    };
}
