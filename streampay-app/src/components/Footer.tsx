import { STREAMPAY_ADDRESS } from "@/lib/contract";
import { shortAddr } from "@/lib/format";

export function Footer() {
  return (
    <footer className="border-t border-border mt-auto">
      <div className="max-w-6xl mx-auto px-6 py-4 grid grid-cols-3 items-center gap-3 font-mono text-[11px] text-muted">
        <span className="justify-self-start">Monad Testnet · 10143</span>
        <span className="justify-self-center text-center">
          Built by{" "}
          <a
            href="https://x.com/ex_machinam"
            target="_blank"
            rel="noreferrer"
            className="text-foreground hover:text-accent transition-colors"
          >
            @ex_machinam ↗
          </a>
        </span>
        <a
          href={`https://testnet.monadexplorer.com/address/${STREAMPAY_ADDRESS}`}
          target="_blank"
          rel="noreferrer"
          className="justify-self-end hover:text-accent transition-colors"
        >
          Kontrat: {shortAddr(STREAMPAY_ADDRESS)} ↗
        </a>
      </div>
    </footer>
  );
}
