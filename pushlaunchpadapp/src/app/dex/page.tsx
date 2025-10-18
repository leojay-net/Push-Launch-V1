import Layout from "@/components/layout/Layout";
import SwapInterface from "@/components/dex/SwapInterface";

export default function DexPage() {
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
                </div>

                <SwapInterface />
            </div>
        </Layout>
    );
}
