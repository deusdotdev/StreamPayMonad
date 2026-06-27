import type { Abi } from "viem";
// Kontrat ABI'si — Foundry çıktısından (out/StreamPay.sol/StreamPay.json)
// kopyalanıp uygulamaya gömüldü. Böylece app, repo köküne/derleme
// çıktısına bağımlı olmadan (örn. Vercel'de) tek başına build alabilir.
import abi from "./streampay-abi.json";

/// Deploy edilmiş StreamPay adresi (Monad testnet).
export const STREAMPAY_ADDRESS =
  "0x151b311C24AEC109C2cA652C3327E7e58551De6f" as const;

/// StreamPay ABI'si.
export const streamPayAbi = abi as Abi;
