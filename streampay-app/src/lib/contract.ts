import type { Abi } from "viem";
// ABI, Foundry build çıktısından üretilip uygulama içine kopyalandı
// (streampay-abi.json). Böylece dağıtım için kontrat klasörüne bağımlı değiliz.
import streamPayAbiJson from "./streampay-abi.json";

/// Deploy edilmiş StreamPay adresi (Monad testnet).
/// Yeniden deploy edilince bu adresi güncelle.
export const STREAMPAY_ADDRESS =
  "0x151b311C24AEC109C2cA652C3327E7e58551De6f" as `0x${string}`;

/// StreamPay ABI'si.
export const streamPayAbi = streamPayAbiJson as Abi;
