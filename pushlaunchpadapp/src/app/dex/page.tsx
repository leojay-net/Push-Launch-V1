import Layout from "@/components/layout/Layout";
import SwapInterface from "@/components/dex/SwapInterface";

interface DexPageProps {
    searchParams?: { [key: string]: string | string[] | undefined };
}

export default function DexPage({ searchParams }: DexPageProps) {
    const tokenParam = Array.isArray(searchParams?.token)
        ? searchParams?.token[0]
        : (searchParams?.token as string | undefined | null) ?? null;

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

                {/* SwapInterface is a client component, pass tokenParam down */}
                <SwapInterface preSelectedToken={tokenParam} />
            </div>
        </Layout>
    );
}
