import type { Abi } from "viem";
// Foundry deploy çıktısı (proje kökündeki deployments.json).
import deployments from "../../../deployments.json";
// Foundry build çıktısındaki kontrat artefaktı (ABI dahil).
import streamPayArtifact from "../../../out/StreamPay.sol/StreamPay.json";

/// Deploy edilmiş StreamPay adresi.
export const STREAMPAY_ADDRESS = deployments.StreamPay as `0x${string}`;

/// StreamPay ABI'si (forge build artefaktından).
export const streamPayAbi = streamPayArtifact.abi as Abi;
