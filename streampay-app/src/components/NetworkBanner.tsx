"use client";

import { useAccount, useSwitchChain } from "wagmi";

import { monadTestnet } from "@/lib/wagmi";

export function NetworkBanner() {
  const { isConnected, chainId } = useAccount();
  const { switchChain, isPending } = useSwitchChain();

  if (!isConnected || chainId === monadTestnet.id) return null;

  return (
    <div className="mb-6 rounded-md border border-amber-300 bg-amber-50 px-4 py-3 flex items-center justify-between gap-3">
      <span className="font-mono text-xs text-amber-800">
        Yanlış ağdasın. StreamPay, Monad Testnet (10143) üzerinde çalışır.
      </span>
      <button
        onClick={() => switchChain({ chainId: monadTestnet.id })}
        disabled={isPending}
        className="shrink-0 font-mono text-xs px-3 py-1.5 rounded-md border border-amber-400 text-amber-800 hover:bg-amber-100 transition-colors disabled:opacity-50"
      >
        {isPending ? "Geçiliyor…" : "Monad Testnet'e Geç"}
      </button>
    </div>
  );
}
