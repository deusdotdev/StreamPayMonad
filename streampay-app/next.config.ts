import path from "path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // contract.ts, üst klasördeki Foundry çıktılarını (deployments.json ve
  // out/StreamPay.sol/StreamPay.json) import ediyor. Bu yüzden workspace
  // kökünü, hem uygulamayı hem de kontrat çıktılarını içeren üst klasöre
  // sabitliyoruz (aksi halde parent import'lar çözümlenemez).
  turbopack: {
    root: path.join(__dirname, ".."),
  },
};

export default nextConfig;
