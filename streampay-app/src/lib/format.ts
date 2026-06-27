import { formatUnits } from "viem";

export function shortAddr(addr?: string) {
  if (!addr) return "";
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

// wei -> MON, sabit ondalık (sadece görsel).
export function toMON(wei: bigint, decimals = 4) {
  return Number(formatUnits(wei, 18)).toFixed(decimals);
}

// Oran dakika bazlı tutulur; saniyelik oran = ratePerMinute / 60.
export function ratePerSecondMON(ratePerMinute: bigint, decimals = 4) {
  return (Number(formatUnits(ratePerMinute, 18)) / 60).toFixed(decimals);
}

// Toplam saniye -> S:DD:SS (saat 24'ü aşabilir).
export function formatDuration(totalSeconds: bigint) {
  if (totalSeconds <= 0n) return "0:00:00";
  const s = totalSeconds % 60n;
  const m = (totalSeconds / 60n) % 60n;
  const h = totalSeconds / 3600n;
  const pad = (n: bigint) => n.toString().padStart(2, "0");
  return `${h}:${pad(m)}:${pad(s)}`;
}
