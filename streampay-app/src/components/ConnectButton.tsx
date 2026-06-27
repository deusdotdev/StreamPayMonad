"use client";

import { useAccount, useConnect, useDisconnect } from "wagmi";
import { injected } from "wagmi/connectors";

import { shortAddr } from "@/lib/format";

export function ConnectButton() {
  const { address, isConnected } = useAccount();
  const { connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected) {
    return (
      <button
        onClick={() => disconnect()}
        className="font-mono text-sm px-3 py-1.5 rounded-md border border-border text-foreground/80 hover:border-accent hover:text-accent transition-colors"
      >
        {shortAddr(address)}
      </button>
    );
  }

  return (
    <button
      onClick={() => connect({ connector: injected() })}
      disabled={isPending}
      className="font-mono text-sm px-3 py-1.5 rounded-md bg-accent text-white hover:bg-accent/90 transition-colors disabled:opacity-50"
    >
      {isPending ? "Bağlanıyor…" : "Cüzdan Bağla"}
    </button>
  );
}
