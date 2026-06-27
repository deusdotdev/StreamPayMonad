import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Hakkında · StreamPay",
  description:
    "StreamPay nasıl çalışır, mimarisi ve gelecek planları — Monad üzerinde gerçek zamanlı ödeme akışları.",
};

const STEPS = [
  {
    title: "Akış oluşturma",
    body: "İşveren createStream çağırır, alıcıyı ve dakika başına akış oranını belirler, başlangıç bütçesini (msg.value) kontrata kilitler. Akış o andan itibaren aktif olur.",
  },
  {
    title: "Hak ediş birikimi",
    body: "Hiçbir işlem gerektirmeden, geçen süre × oran kadar hak ediş alıcı için sürekli birikir. Kontrat bunu lastClaimTimestamp ile takip eder; birikim kilitli bütçeyi aşamaz.",
  },
  {
    title: "Talep (claim)",
    body: "Alıcı dilediği an claim çağırır; o ana kadar biriken tutar cüzdanına transfer edilir ve sayaç güncellenir. Çekme işlemi tamamen alıcının inisiyatifindedir.",
  },
  {
    title: "Otomatik likidasyon",
    body: "Bütçe sıfıra inerse akış kendiliğinden pasifleşir. Dışarıdan bir bota veya keeper'a gerek yoktur — mantık tamamen zincir üstündedir.",
  },
];

const FEATURES = [
  {
    title: "Oran ayarı",
    body: "İşveren adjustRate ile akış hızını değiştirebilir. Değişiklikten önce eski hızla biriken hak ediş dondurulur, böylece alıcı hiçbir şey kaybetmez.",
  },
  {
    title: "Güvenli durdurma",
    body: "pauseStream çağrıldığında alıcının o ana kadarki hak edişi rezerve edilir, kalan bütçe işverene iade edilir. Çalışan emeğinin karşılığını alır.",
  },
  {
    title: "Acil çekim",
    body: "İşveren uzun süredir bütçe eklemediyse, alıcı emergencyWithdraw ile kalan bakiyeyi güvenle çekebilir.",
  },
  {
    title: "Gelecek hak satışı",
    body: "Alıcı, gelecekteki belirli bir zaman dilimindeki kazanma hakkını listFutureClaim ile listeleyip iskontolu olarak bir alıcıya satabilir (buyFutureClaim). Anlık likidite sağlar.",
  },
];

const ROADMAP = [
  {
    tag: "DeFi teminatı",
    body: "Aktif bir ödeme akışı, öngörülebilir gelecek nakit akışı demektir. Bu akışlar teminat olarak kilitlenerek DeFi protokollerinde kredi çekmek için kullanılabilecek — maaşını beklemeden borçlanma.",
  },
  {
    tag: "Akış devri",
    body: "Bir akışın tamamının (yalnızca belirli bir dilimin değil) başka bir adrese kalıcı olarak devredilmesi. Alacaklar ikincil piyasada serbestçe alınıp satılabilir hale gelecek.",
  },
  {
    tag: "Kredi & faktoring",
    body: "Gelecek hak satışı mekanizmasının üzerine kurulu, akış bazlı faktoring ve teminatlı borç verme havuzları. Likidite sağlayıcılar iskontolu gelecek kazançlardan getiri elde edecek.",
  },
  {
    tag: "ERC-20 & çoklu varlık",
    body: "Yalnızca yerel MON değil, ERC-20 token'larla da akış desteği; abonelikler, vesting ve kurumsal bordro senaryoları.",
  },
];

export default function AboutPage() {
  return (
    <main className="flex-1 w-full max-w-3xl mx-auto px-6 py-14">
      <header className="mb-12">
        <h1 className="text-3xl sm:text-4xl font-semibold tracking-tight">
          StreamPay <span className="text-accent">nasıl çalışır?</span>
        </h1>
        <p className="mt-4 text-muted leading-relaxed">
          StreamPay, Monad üzerinde gerçek zamanlı ödeme akışı protokolüdür.
          Ödemeler tek seferde değil; saniye saniye, sürekli akar. İşveren bir
          bütçe kilitler, alıcı süre ilerledikçe biriken tutarı dilediği an
          çeker. Tüm mantık zincir üstündedir; aracıya veya bekçi bota gerek
          yoktur.
        </p>
      </header>

      <section className="mb-14">
        <h2 className="text-[11px] uppercase tracking-[0.2em] text-muted mb-5">
          Temel akış
        </h2>
        <ol className="space-y-4">
          {STEPS.map((s, i) => (
            <li
              key={s.title}
              className="rounded-xl border border-border bg-card p-5 flex gap-4"
            >
              <span className="font-mono text-accent text-sm shrink-0 mt-0.5">
                0{i + 1}
              </span>
              <div>
                <h3 className="font-medium mb-1">{s.title}</h3>
                <p className="text-sm text-muted leading-relaxed">{s.body}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <section className="mb-14">
        <h2 className="text-[11px] uppercase tracking-[0.2em] text-muted mb-5">
          Öne çıkan özellikler
        </h2>
        <div className="grid sm:grid-cols-2 gap-4">
          {FEATURES.map((f) => (
            <div key={f.title} className="rounded-xl border border-border bg-card p-5">
              <h3 className="font-medium mb-1">{f.title}</h3>
              <p className="text-sm text-muted leading-relaxed">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="mb-14">
        <h2 className="text-[11px] uppercase tracking-[0.2em] text-muted mb-2">
          Gelecek planları
        </h2>
        <p className="text-sm text-muted mb-5 leading-relaxed">
          StreamPay&apos;in uzun vadeli vizyonu, ödeme akışlarını yalnızca bir
          transfer aracı değil, üzerine finansal ürünler kurulabilecek bir
          temel katman haline getirmek.
        </p>
        <div className="space-y-3">
          {ROADMAP.map((r) => (
            <div
              key={r.tag}
              className="rounded-xl border border-border p-5 flex flex-col sm:flex-row sm:items-baseline gap-2 sm:gap-4"
            >
              <span className="font-mono text-xs text-accent shrink-0 sm:w-40">
                {r.tag}
              </span>
              <p className="text-sm text-muted leading-relaxed">{r.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="rounded-xl border border-border bg-card p-6 text-center">
        <p className="text-sm text-muted">
          Geliştirici güncellemeleri ve yol haritası için:
        </p>
        <a
          href="https://x.com/ex_machinam"
          target="_blank"
          rel="noreferrer"
          className="inline-block mt-2 font-mono text-accent hover:underline underline-offset-4"
        >
          @ex_machinam ↗
        </a>
      </section>
    </main>
  );
}
