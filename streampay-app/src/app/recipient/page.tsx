"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

import { NetworkBanner } from "@/components/NetworkBanner";
import { STREAMPAY_ADDRESS, streamPayAbi } from "@/lib/contract";
import { ratePerSecondMON, shortAddr, toMON } from "@/lib/format";
import { type StreamData, ZERO_ADDRESS } from "@/lib/stream";

function LiveClaimable({
  ratePerMinute,
  lastClaimTimestamp,
  employerBalance,
  active,
}: {
  ratePerMinute: bigint;
  lastClaimTimestamp: bigint;
  employerBalance: bigint;
  active: boolean;
}) {
  // block.timestamp'i lokal saatle tahmin ediyoruz (gerçek RPC çağrısı yok).
  const [nowSec, setNowSec] = useState(() => Math.floor(Date.now() / 1000));

  useEffect(() => {
    if (!active) return;
    const t = setInterval(() => setNowSec(Math.floor(Date.now() / 1000)), 100);
    return () => clearInterval(t);
  }, [active]);

  const claimableWei = useMemo(() => {
    if (!active) return 0n;
    const elapsed = BigInt(nowSec) - lastClaimTimestamp;
    if (elapsed <= 0n) return 0n;
    const accrued = (elapsed * ratePerMinute) / 60n;
    return accrued > employerBalance ? employerBalance : accrued;
  }, [active, nowSec, lastClaimTimestamp, ratePerMinute, employerBalance]);

  return (
    <div className="text-center py-2">
      <div className="text-[11px] uppercase tracking-[0.2em] text-muted mb-1">
        Talep Edilebilir
      </div>
      <div className="stream-counter text-4xl sm:text-5xl tabular-nums">
        {toMON(claimableWei)}
        <span className="text-base text-accent/60 ml-2">MON</span>
      </div>
    </div>
  );
}

function StreamCard({
  streamId,
  myAddress,
}: {
  streamId: number;
  myAddress?: `0x${string}`;
}) {
  const { data, refetch, isLoading } = useReadContract({
    address: STREAMPAY_ADDRESS,
    abi: streamPayAbi,
    functionName: "streams",
    args: [BigInt(streamId)],
  });

  const {
    writeContract,
    data: hash,
    isPending,
    reset,
    error: writeError,
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const [showSuccess, setShowSuccess] = useState(false);

  useEffect(() => {
    if (!isSuccess) return;
    setShowSuccess(true);
    refetch();
    const t = setTimeout(() => {
      setShowSuccess(false);
      reset();
    }, 2600);
    return () => clearTimeout(t);
  }, [isSuccess, refetch, reset]);

  if (isLoading) {
    return (
      <div className="rounded-xl border border-border p-6 text-muted font-mono text-sm">
        Stream #{streamId} yükleniyor…
      </div>
    );
  }

  const s = data as StreamData | undefined;
  if (!s || s[0] === ZERO_ADDRESS) {
    return (
      <div className="rounded-xl border border-border p-6 text-muted font-mono text-sm">
        Stream #{streamId} bulunamadı.
      </div>
    );
  }

  const [employer, recipient, ratePerMinute, lastClaim, employerBalance, , active] = s;
  const isRecipient =
    !!myAddress && recipient.toLowerCase() === myAddress.toLowerCase();

  const busy = isPending || isConfirming;

  return (
    <div className="relative rounded-xl border border-border bg-card p-6 overflow-hidden">
      <div className="flex items-center justify-between mb-4">
        <span className="font-mono text-xs text-muted">STREAM #{streamId}</span>
        <span
          className={`font-mono text-[10px] uppercase tracking-wider px-2 py-0.5 rounded-full border ${
            active ? "border-accent text-accent" : "border-border text-muted"
          }`}
        >
          {active ? "aktif" : "durduruldu"}
        </span>
      </div>

      <LiveClaimable
        ratePerMinute={ratePerMinute}
        lastClaimTimestamp={lastClaim}
        employerBalance={employerBalance}
        active={active}
      />

      <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 font-mono text-sm">
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-muted">İşveren</dt>
          <dd className="text-foreground/90">{shortAddr(employer)}</dd>
        </div>
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-muted">Oran</dt>
          <dd className="text-foreground/90">
            {ratePerSecondMON(ratePerMinute)} MON/sn
          </dd>
        </div>
        <div className="col-span-2">
          <dt className="text-[11px] uppercase tracking-wider text-muted">
            Kalan Bütçe
          </dt>
          <dd className="text-foreground/90 tabular-nums">
            {toMON(employerBalance)} MON
          </dd>
        </div>
      </dl>

      <div className="mt-5">
        <button
          onClick={() =>
            writeContract({
              address: STREAMPAY_ADDRESS,
              abi: streamPayAbi,
              functionName: "claim",
              args: [BigInt(streamId)],
            })
          }
          disabled={!isRecipient || !active || busy}
          className="w-full font-mono text-sm py-2.5 rounded-md bg-accent text-white hover:bg-accent/90 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {busy ? (isConfirming ? "Onaylanıyor…" : "Gönderiliyor…") : "Şimdi Claim Et"}
        </button>
        {!isRecipient && (
          <p className="mt-2 text-center text-[11px] text-muted font-mono">
            Yalnızca alıcı (recipient) claim edebilir.
          </p>
        )}
        {writeError && (
          <p className="mt-2 text-center text-[11px] text-red-600 font-mono">
            İşlem reddedildi.
          </p>
        )}
      </div>

      {showSuccess && (
        <div className="absolute inset-0 flex items-center justify-center bg-background/85 backdrop-blur-sm success-pop">
          <div className="flex flex-col items-center gap-2">
            <svg
              width="56"
              height="56"
              viewBox="0 0 24 24"
              fill="none"
              stroke="var(--accent)"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M20 6 9 17l-5-5" />
            </svg>
            <span className="font-mono text-sm text-accent">Claim başarılı</span>
          </div>
        </div>
      )}
    </div>
  );
}

export default function RecipientPage() {
  const { address, isConnected } = useAccount();

  const [idInput, setIdInput] = useState("");
  const [manualId, setManualId] = useState<number | null>(null);

  const { data: nextIdData } = useReadContract({
    address: STREAMPAY_ADDRESS,
    abi: streamPayAbi,
    functionName: "nextStreamId",
    query: { enabled: isConnected },
  });
  const nextId = nextIdData ? Number(nextIdData as bigint) : 0;

  const contracts = useMemo(
    () =>
      Array.from({ length: nextId }, (_, i) => ({
        address: STREAMPAY_ADDRESS,
        abi: streamPayAbi,
        functionName: "streams" as const,
        args: [BigInt(i)] as const,
      })),
    [nextId],
  );

  const { data: allStreams } = useReadContracts({
    contracts,
    query: { enabled: isConnected && nextId > 0 },
  });

  const myStreamIds = useMemo(() => {
    if (!allStreams || !address) return [];
    const ids: number[] = [];
    allStreams.forEach((r, i) => {
      const s = r.result as StreamData | undefined;
      if (s && s[1].toLowerCase() === address.toLowerCase() && s[6]) {
        ids.push(i);
      }
    });
    return ids;
  }, [allStreams, address]);

  return (
    <main className="flex-1 w-full max-w-6xl mx-auto px-6 py-10">
      <div className="mb-8">
        <h1 className="font-mono text-2xl tracking-tight">Alıcı Paneli</h1>
        <p className="text-sm text-muted mt-1">
          Sana akan ödemeleri canlı izle ve dilediğin an talep et.
        </p>
      </div>

      {!isConnected ? (
        <div className="text-center text-muted font-mono text-sm py-24">
          Başlamak için sağ üstten cüzdanını bağla.
        </div>
      ) : (
        <div className="space-y-8">
          <NetworkBanner />
          <section className="max-w-md">
            <label className="block text-[11px] uppercase tracking-[0.2em] text-muted mb-2">
              Stream ID ile görüntüle
            </label>
            <div className="flex gap-2">
              <input
                value={idInput}
                onChange={(e) => setIdInput(e.target.value.replace(/[^0-9]/g, ""))}
                placeholder="örn. 0"
                inputMode="numeric"
                className="flex-1 font-mono text-sm bg-white border border-border rounded-md px-3 py-2 outline-none focus:border-accent"
              />
              <button
                onClick={() => setManualId(idInput === "" ? null : Number(idInput))}
                className="font-mono text-sm px-4 rounded-md border border-border hover:border-accent hover:text-accent transition-colors"
              >
                Görüntüle
              </button>
            </div>
          </section>

          {manualId !== null && (
            <div className="max-w-sm">
              <StreamCard streamId={manualId} myAddress={address} />
            </div>
          )}

          <section>
            <h2 className="text-[11px] uppercase tracking-[0.2em] text-muted mb-3">
              Alıcısı olduğun aktif stream&apos;ler
            </h2>
            {myStreamIds.length === 0 ? (
              <p className="text-muted font-mono text-sm">
                Aktif stream bulunamadı. Bir akış başlatmak için{" "}
                <Link
                  href="/employer"
                  className="text-accent hover:underline underline-offset-2"
                >
                  işveren paneline
                </Link>{" "}
                geç.
              </p>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {myStreamIds
                  .filter((id) => id !== manualId)
                  .map((id) => (
                    <StreamCard key={id} streamId={id} myAddress={address} />
                  ))}
              </div>
            )}
          </section>
        </div>
      )}
    </main>
  );
}
