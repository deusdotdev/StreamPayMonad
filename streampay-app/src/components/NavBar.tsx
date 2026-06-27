"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { ConnectButton } from "./ConnectButton";

const LINKS = [
  { href: "/recipient", label: "Alıcı" },
  { href: "/employer", label: "İşveren" },
  { href: "/about", label: "Hakkında" },
];

export function NavBar() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-20 border-b border-border bg-background/80 backdrop-blur-md">
      <div className="max-w-6xl mx-auto px-6 h-14 flex items-center justify-between gap-4">
        <div className="flex items-center gap-5">
          <Link href="/" className="font-mono text-base tracking-tight shrink-0">
            Stream<span className="text-accent">Pay</span>
          </Link>
          <nav className="flex items-center gap-1">
            {LINKS.map((l) => {
              const active = pathname === l.href;
              return (
                <Link
                  key={l.href}
                  href={l.href}
                  className={`font-mono text-sm px-2.5 py-1 rounded-md transition-colors ${
                    active
                      ? "text-foreground bg-card"
                      : "text-muted hover:text-foreground"
                  }`}
                >
                  {l.label}
                </Link>
              );
            })}
          </nav>
        </div>
        <ConnectButton />
      </div>
    </header>
  );
}
