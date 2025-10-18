import Layout from "@/components/layout/Layout";
import LiquidityInterface from "@/components/liquidity/LiquidityInterface";

export default function LiquidityPage() {
    return (
        <Layout>
            <div className="max-w-md mx-auto">
                <div className="mb-8">
                    <h1 className="text-3xl font-bold text-gray-900 mb-2">
                        Manage Liquidity
                    </h1>
                    <p className="text-gray-600">
                        Add or remove liquidity to earn trading fees from swaps
                    </p>
                </div>

                <LiquidityInterface />
            </div>
        </Layout>
    );
}
