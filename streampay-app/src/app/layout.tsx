import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { Footer } from "@/components/Footer";
import { NavBar } from "@/components/NavBar";
import { Providers } from "./providers";

// Body fontu: temiz sans-serif.
const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

// Display/sayaç fontu: monospace ("canlı veri" hissi).
const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "StreamPay",
  description: "Saniye saniye akan ödemeler — Monad testnet üzerinde.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="tr"
      className={`${inter.variable} ${jetbrainsMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <Providers>
          <NavBar />
          {children}
          <Footer />
        </Providers>
      </body>
    </html>
  );
}
