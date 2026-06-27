"use client";

import { useEffect, useMemo, useState } from "react";
import { formatUnits, isAddress, parseEther } from "viem";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

import { NetworkBanner } from "@/components/NetworkBanner";
import { STREAMPAY_ADDRESS, streamPayAbi } from "@/lib/contract";
import { formatDuration, ratePerSecondMON, shortAddr, toMON } from "@/lib/format";
import { type StreamData, ZERO_ADDRESS } from "@/lib/stream";

type RateUnit = "sec" | "day";

// Girilen değeri (MON/saniye veya MON/gün) kontratın beklediği
// ratePerMinute (wei) birimine çevirir.
function toRatePerMinuteWei(value: string, unit: RateUnit): bigint | null {
  if (!value || Number(value) <= 0) return null;
  try {
    const base = parseEther(value); // wei / (seçilen birim)
    return unit === "sec" ? base * 60n : base / 1440n; // 1 gün = 1440 dakika
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------

function NewStreamForm({ onCreated }: { onCreated: () => void }) {
  const [recipient, setRecipient] = useState("");
  const [rateValue, setRateValue] = useState("");
  const [rateUnit, setRateUnit] = useState<RateUnit>("day");
  const [deposit, setDeposit] = useState("");

  const ratePerMinuteWei = useMemo(
    () => toRatePerMinuteWei(rateValue, rateUnit),
    [rateValue, rateUnit],
  );

  const depositWei = useMemo(() => {
    if (!deposit || Number(deposit) <= 0) return null;
    try {
      return parseEther(deposit);
    } catch {
      return null;
    }
  }, [deposit]);

  const recipientValid = isAddress(recipient);

  // Türetilmiş gösterim.
  const derived = useMemo(() => {
    if (!ratePerMinuteWei) return null;
    const perMinute = Number(formatUnits(ratePerMinuteWei, 18));
    return {
      perSecond: (perMinute / 60).toFixed(6),
      perDay: (perMinute * 1440).toFixed(4),
    };
  }, [ratePerMinuteWei]);

  const { writeContract, data: hash, isPending, reset, error } =
    useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });
  const [showSuccess, setShowSuccess] = useState(false);

  useEffect(() => {
    if (!isSuccess) return;
    setShowSuccess(true);
    setRecipient("");
    setRateValue("");
    setDeposit("");
    onCreated();
    const t = setTimeout(() => {
      setShowSuccess(false);
      reset();
    }, 2600);
    return () => clearTimeout(t);
  }, [isSuccess, onCreated, reset]);

  const canSubmit =
    recipientValid && !!ratePerMinuteWei && !!depositWei && !isPending && !isConfirming;
  const busy = isPending || isConfirming;

  return (
    <section className="relative rounded-xl border border-border bg-card p-6 overflow-hidden">
      <h2 className="font-mono text-sm mb-5">Yeni Akış Başlat</h2>

      <div className="space-y-4">
        <div>
          <label className="block text-[11px] uppercase tracking-wider text-muted mb-1.5">
            Alıcı adresi
          </label>
          <input
            value={recipient}
            onChange={(e) => setRecipient(e.target.value.trim())}
            placeholder="0x…"
            className={`w-full font-mono text-sm bg-white border rounded-md px-3 py-2 outline-none focus:border-accent ${
              recipient && !recipientValid ? "border-red-400" : "border-border"
            }`}
          />
        </div>

        <div>
          <label className="block text-[11px] uppercase tracking-wider text-muted mb-1.5">
            Akış oranı
          </label>
          <div className="flex gap-2">
            <input
              value={rateValue}
              onChange={(e) => setRateValue(e.target.value.replace(/[^0-9.]/g, ""))}
              placeholder="örn. 10"
              inputMode="decimal"
              className="flex-1 font-mono text-sm bg-white border border-border rounded-md px-3 py-2 outline-none focus:border-accent"
            />
            <select
              value={rateUnit}
              onChange={(e) => setRateUnit(e.target.value as RateUnit)}
              className="font-mono text-sm bg-white border border-border rounded-md px-2 outline-none focus:border-accent"
            >
              <option value="day">MON / gün</option>
              <option value="sec">MON / saniye</option>
            </select>
          </div>
          {derived && (
            <p className="mt-1.5 text-[11px] font-mono text-muted">
              = {derived.perSecond} MON/sn · {derived.perDay} MON/gün
            </p>
          )}
        </div>

        <div>
          <label className="block text-[11px] uppercase tracking-wider text-muted mb-1.5">
            Başlangıç bakiyesi (MON)
          </label>
          <input
            value={deposit}
            onChange={(e) => setDeposit(e.target.value.replace(/[^0-9.]/g, ""))}
            placeholder="örn. 5"
            inputMode="decimal"
            className="w-full font-mono text-sm bg-white border border-border rounded-md px-3 py-2 outline-none focus:border-accent"
          />
        </div>

        <button
          onClick={() =>
            writeContract({
              address: STREAMPAY_ADDRESS,
              abi: streamPayAbi,
              functionName: "createStream",
              args: [recipient as `0x${string}`, ratePerMinuteWei!],
              value: depositWei!,
            })
          }
          disabled={!canSubmit}
          className="w-full font-mono text-sm py-2.5 rounded-md bg-accent text-white hover:bg-accent/90 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          {busy ? (isConfirming ? "Onaylanıyor…" : "Gönderiliyor…") : "Akışı Başlat"}
        </button>
        {error && (
          <p className="text-center text-[11px] text-red-600 font-mono">
            İşlem reddedildi.
          </p>
        )}
      </div>

      {showSuccess && (
        <div className="absolute inset-0 flex items-center justify-center bg-background/80 backdrop-blur-sm success-pop">
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
            <span className="font-mono text-sm text-accent">Akış başlatıldı</span>
          </div>
        </div>
      )}
    </section>
  );
}

// ---------------------------------------------------------------------------

function EmployerStreamCard({
  streamId,
  onChanged,
}: {
  streamId: number;
  onChanged: () => void;
}) {
  const { data, refetch } = useReadContract({
    address: STREAMPAY_ADDRESS,
    abi: streamPayAbi,
    functionName: "streams",
    args: [BigInt(streamId)],
  });

  // adjustRate
  const [newRate, setNewRate] = useState("");
  const adjust = useWriteContract();
  const adjustReceipt = useWaitForTransactionReceipt({ hash: adjust.data });

  // pauseStream
  const [showPause, setShowPause] = useState(false);
  const pause = useWriteContract();
  const pauseReceipt = useWaitForTransactionReceipt({ hash: pause.data });

  useEffect(() => {
    if (adjustReceipt.isSuccess) {
      setNewRate("");
      refetch();
      onChanged();
      adjust.reset();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [adjustReceipt.isSuccess]);

  useEffect(() => {
    if (pauseReceipt.isSuccess) {
      setShowPause(false);
      refetch();
      onChanged();
      pause.reset();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pauseReceipt.isSuccess]);

  const s = data as StreamData | undefined;
  if (!s || s[0] === ZERO_ADDRESS) return null;

  const [, recipient, ratePerMinute, , employerBalance, , active] = s;
  const durationSeconds =
    ratePerMinute > 0n ? (employerBalance * 60n) / ratePerMinute : 0n;

  const newRpm = toRatePerMinuteWei(newRate, "sec");
  const adjustBusy = adjust.isPending || adjustReceipt.isLoading;
  const pauseBusy = pause.isPending || pauseReceipt.isLoading;

  return (
    <div className="relative rounded-xl border border-border bg-card p-6 overflow-hidden">
      <div className="flex items-center justify-between mb-4">
        <span className="font-mono text-xs text-muted">STREAM #{streamId}</span>
        <span className="font-mono text-[10px] uppercase tracking-wider px-2 py-0.5 rounded-full border border-accent/40 text-accent">
          aktif
        </span>
      </div>

      <dl className="grid grid-cols-2 gap-x-4 gap-y-3 font-mono text-sm">
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-muted">Alıcı</dt>
          <dd className="text-foreground/90">{shortAddr(recipient)}</dd>
        </div>
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-muted">Oran</dt>
          <dd className="text-foreground/90">
            {ratePerSecondMON(ratePerMinute)} MON/sn
          </dd>
        </div>
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-muted">
            Kalan Bütçe
          </dt>
          <dd className="text-foreground/90 tabular-nums">
            {toMON(employerBalance)} MON
          </dd>
        </div>
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-muted">
            Yetecek Süre
          </dt>
          <dd className="text-accent tabular-nums">
            {formatDuration(durationSeconds)}
          </dd>
        </div>
      </dl>

      {/* Hızı değiştir (inline) */}
      <div className="mt-5">
        <label className="block text-[11px] uppercase tracking-wider text-muted mb-1.5">
          Hızı değiştir (MON/sn)
        </label>
        <div className="flex gap-2">
          <input
            value={newRate}
            onChange={(e) => setNewRate(e.target.value.replace(/[^0-9.]/g, ""))}
            placeholder="yeni oran"
            inputMode="decimal"
            className="flex-1 font-mono text-sm bg-white border border-border rounded-md px-3 py-2 outline-none focus:border-accent"
          />
          <button
            onClick={() => {
              if (!newRpm) return;
              adjust.writeContract({
                address: STREAMPAY_ADDRESS,
                abi: streamPayAbi,
                functionName: "adjustRate",
                args: [BigInt(streamId), newRpm],
              });
            }}
            disabled={!newRpm || adjustBusy}
            className="font-mono text-sm px-4 rounded-md border border-border hover:border-accent hover:text-accent transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {adjustBusy ? "…" : "Değiştir"}
          </button>
        </div>
      </div>

      {/* Akışı durdur */}
      <button
        onClick={() => setShowPause(true)}
        disabled={pauseBusy}
        className="mt-3 w-full font-mono text-sm py-2 rounded-md border border-red-300 text-red-600 hover:bg-red-50 transition-colors disabled:opacity-40"
      >
        {pauseBusy ? "Durduruluyor…" : "Akışı Durdur"}
      </button>

      {showPause && (
        <div className="absolute inset-0 flex items-center justify-center bg-background/85 backdrop-blur-sm p-6">
          <div className="w-full max-w-sm rounded-xl border border-border bg-background p-5 text-center">
            <p className="font-mono text-sm mb-1">Akışı durdur?</p>
            <p className="text-[12px] text-muted mb-5">
              Alıcının o ana kadarki hak edişi rezerve edilir, kalan bütçe sana
              iade edilir. Bu işlem{" "}
              <span className="text-red-600">geri alınamaz</span>.
            </p>
            <div className="flex gap-2">
              <button
                onClick={() => setShowPause(false)}
                className="flex-1 font-mono text-sm py-2 rounded-md border border-border hover:border-foreground/30 transition-colors"
              >
                Vazgeç
              </button>
              <button
                onClick={() =>
                  pause.writeContract({
                    address: STREAMPAY_ADDRESS,
                    abi: streamPayAbi,
                    functionName: "pauseStream",
                    args: [BigInt(streamId)],
                  })
                }
                disabled={pauseBusy}
                className="flex-1 font-mono text-sm py-2 rounded-md bg-red-600 text-white border border-red-600 hover:bg-red-700 transition-colors disabled:opacity-40"
              >
                {pauseBusy ? "…" : "Evet, durdur"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------

export default function EmployerPage() {
  const { address, isConnected } = useAccount();

  const { data: nextIdData, refetch: refetchNextId } = useReadContract({
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

  const { data: allStreams, refetch: refetchAll } = useReadContracts({
    contracts,
    query: { enabled: isConnected && nextId > 0 },
  });

  const myStreamIds = useMemo(() => {
    if (!allStreams || !address) return [];
    const ids: number[] = [];
    allStreams.forEach((r, i) => {
      const s = r.result as StreamData | undefined;
      if (s && s[0].toLowerCase() === address.toLowerCase() && s[6]) {
        ids.push(i);
      }
    });
    return ids;
  }, [allStreams, address]);

  const onChanged = () => {
    refetchNextId();
    refetchAll();
  };

  return (
    <main className="flex-1 w-full max-w-6xl mx-auto px-6 py-10">
      <div className="mb-8">
        <h1 className="font-mono text-2xl tracking-tight">İşveren Paneli</h1>
        <p className="text-sm text-muted mt-1">
          Yeni akışlar başlat, oranları yönet ve akışları durdur.
        </p>
      </div>

      {!isConnected ? (
        <div className="text-center text-muted font-mono text-sm py-24">
          Başlamak için sağ üstten cüzdanını bağla.
        </div>
      ) : (
        <div className="space-y-6">
          <NetworkBanner />
          <div className="grid gap-6 items-start lg:grid-cols-[minmax(320px,380px)_1fr]">
            <NewStreamForm onCreated={onChanged} />

            <section>
              <h2 className="text-[11px] uppercase tracking-[0.2em] text-muted mb-3">
                İşvereni olduğun aktif stream&apos;ler
              </h2>
              {myStreamIds.length === 0 ? (
                <p className="text-muted font-mono text-sm">Aktif stream bulunamadı.</p>
              ) : (
                <div className="grid gap-4 xl:grid-cols-2">
                  {myStreamIds.map((id) => (
                    <EmployerStreamCard key={id} streamId={id} onChanged={onChanged} />
                  ))}
                </div>
              )}
            </section>
          </div>
        </div>
      )}
    </main>
  );
}
