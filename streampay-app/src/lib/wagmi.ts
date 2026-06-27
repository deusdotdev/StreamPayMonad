import { http, createConfig } from "wagmi";
import { defineChain } from "viem";
import { injected } from "wagmi/connectors";

const MONAD_RPC_URL = "https://testnet-rpc.monad.xyz";

/// Monad testnet'i custom chain olarak tanımlıyoruz.
export const monadTestnet = defineChain({
  id: 10143,
  name: "Monad Testnet",
  nativeCurrency: { name: "Monad", symbol: "MON", decimals: 18 },
  rpcUrls: {
    default: { http: [MONAD_RPC_URL] },
  },
  blockExplorers: {
    default: {
      name: "Monad Explorer",
      url: "https://testnet.monadexplorer.com",
    },
  },
  testnet: true,
});

export const config = createConfig({
  chains: [monadTestnet],
  // MetaMask / Rabby gibi tarayıcıya enjekte edilen cüzdanlar.
  connectors: [injected()],
  transports: {
    [monadTestnet.id]: http(MONAD_RPC_URL),
  },
  // Next.js App Router (sunucu tarafı render) için.
  ssr: true,
});

declare module "wagmi" {
  interface Register {
    config: typeof config;
  }
}
