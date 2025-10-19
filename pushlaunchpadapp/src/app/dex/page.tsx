"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Layout from "@/components/layout/Layout";
import SwapInterface from "@/components/dex/SwapInterface";

export default function DexPage() {
    const searchParams = useSearchParams();
    const tokenParam = searchParams.get("token");

    return (
        <Layout>
            <div className="max-w-md mx-auto">
                <div className="mb-8">
                    <h1 className="text-3xl font-bold text-gray-900 mb-2">
                        Swap Tokens
                    </h1>
                    <p className="text-gray-600">
                        Trade tokens instantly across chains with universal transactions
                    </p>
                    {tokenParam && (
                        <p className="text-sm text-emerald-600 mt-2">
                            Trading graduated token {tokenParam.substring(0, 6)}...{tokenParam.substring(tokenParam.length - 4)}
                        </p>
                    )}
                </div>

                <SwapInterface preSelectedToken={tokenParam} />
            </div>
        </Layout>
    );
}
