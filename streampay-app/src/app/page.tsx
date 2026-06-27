"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

// Tanıtım amaçlı, sadece görsel akan sayaç (zincirden bağımsız).
function FlowDemo() {
  const start = useRef(Date.now());
  const [amount, setAmount] = useState(0);

  useEffect(() => {
    const t = setInterval(() => {
      const elapsed = (Date.now() - start.current) / 1000;
      // 1 MON / dakika hızında akıyormuş gibi.
      setAmount((elapsed / 60) % 1000);
    }, 100);
    return () => clearInterval(t);
  }, []);

  return (
    <div className="text-center">
      <div className="text-[11px] uppercase tracking-[0.2em] text-muted mb-2">
        Şu an akıyor
      </div>
      <div className="stream-counter text-5xl sm:text-6xl tabular-nums">
        {amount.toFixed(4)}
        <span className="text-xl text-accent/60 ml-2">MON</span>
      </div>
    </div>
  );
}

const FEATURES = [
  {
    title: "Akış Başlat",
    body: "İşveren bir bütçe kilitler; ödeme saniye saniye, otomatik akar.",
  },
  {
    title: "Canlı Talep Et",
    body: "Alıcı biriken tutarı istediği an çeker. Aradaki bekçi/bot gerekmez.",
  },
  {
    title: "Geleceği Sat",
    body: "Alıcı gelecekteki kazancını iskontolu olarak bir alıcıya devredebilir.",
  },
];

export default function Landing() {
  return (
    <main className="flex-1 w-full max-w-5xl mx-auto px-6 py-16">
      <section className="text-center">
        <h1 className="text-4xl sm:text-5xl font-semibold tracking-tight">
          Zaman aktıkça, <span className="text-accent">para da aksın</span>.
        </h1>
        <p className="mt-4 text-muted max-w-xl mx-auto">
          StreamPay, Monad üzerinde gerçek zamanlı ödeme akışı protokolü.
          Maaşlar, abonelikler ve hizmet ödemeleri saniye saniye birikir; alıcı
          dilediği an talep eder.
        </p>

        <div className="mt-12 rounded-2xl border border-border bg-card py-10">
          <FlowDemo />
        </div>

        <div className="mt-8 flex items-center justify-center gap-3">
          <Link
            href="/employer"
            className="font-mono text-sm px-5 py-2.5 rounded-md bg-accent text-white hover:bg-accent/90 transition-colors"
          >
            İşveren Paneli
          </Link>
          <Link
            href="/recipient"
            className="font-mono text-sm px-5 py-2.5 rounded-md border border-border text-foreground hover:border-accent hover:text-accent transition-colors"
          >
            Alıcı Paneli
          </Link>
        </div>
      </section>

      <section className="mt-20 grid sm:grid-cols-3 gap-4">
        {FEATURES.map((f, i) => (
          <div key={f.title} className="rounded-xl border border-border bg-card p-5">
            <div className="font-mono text-xs text-accent mb-2">0{i + 1}</div>
            <h3 className="font-medium mb-1">{f.title}</h3>
            <p className="text-sm text-muted leading-relaxed">{f.body}</p>
          </div>
        ))}
      </section>

      <section className="mt-20 text-center">
        <h2 className="text-xl font-medium">Nasıl çalışır?</h2>
        <ol className="mt-6 max-w-md mx-auto text-left space-y-3 font-mono text-sm text-muted">
          <li>
            <span className="text-accent">1.</span> İşveren{" "}
            <span className="text-foreground">createStream</span> ile alıcıya bir
            akış açar ve bütçeyi kilitler.
          </li>
          <li>
            <span className="text-accent">2.</span> Süre ilerledikçe alıcının hak
            edişi otomatik birikir.
          </li>
          <li>
            <span className="text-accent">3.</span> Alıcı{" "}
            <span className="text-foreground">claim</span> ile biriken tutarı
            cüzdanına çeker.
          </li>
          <li>
            <span className="text-accent">4.</span> Bütçe biterse akış kendiliğinden
            durur — dışarıdan bir bota ihtiyaç yok.
          </li>
        </ol>
      </section>
    </main>
  );
}
