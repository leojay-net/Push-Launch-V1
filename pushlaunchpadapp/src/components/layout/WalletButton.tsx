"use client";

import dynamic from "next/dynamic";

// Dynamically import to guarantee client-only rendering
const PushUniversalAccountButton = dynamic(
    () => import("@pushchain/ui-kit").then((m) => m.PushUniversalAccountButton),
    { ssr: false }
);

export default function WalletButton() {
    return (
        <div className="flex items-center">
            <PushUniversalAccountButton />
        </div>
    );
}
