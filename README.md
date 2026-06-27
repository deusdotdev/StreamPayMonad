# StreamPay

**Monad üzerinde gerçek zamanlı ödeme akışı protokolü.**

Ödemeler tek seferde değil, **saniye saniye** akar. İşveren bir bütçe kilitler;
alıcının hak edişi zaman ilerledikçe otomatik birikir ve alıcı dilediği an talep
eder. Tüm mantık zincir üstündedir — aracıya, bankaya veya bekçi bota gerek yoktur.

> Deploy adresi (Monad Testnet · 10143): `0x151b311C24AEC109C2cA652C3327E7e58551De6f`

---

## Özellikler

- **Akış oluşturma** — İşveren `createStream` ile alıcı + dakikalık oranı belirler ve başlangıç bütçesini (`msg.value`) kilitler.
- **Sürekli birikim** — Hiçbir işlem gerekmeden, `geçen süre × oran` kadar hak ediş alıcı için birikir; birikim kilitli bütçeyi aşamaz.
- **İstediğin an talep** — Alıcı `claim` ile biriken tutarı cüzdanına çeker.
- **Otomatik likidasyon** — Bütçe sıfıra inince akış kendiliğinden pasifleşir. Keeper/bot gerekmez.
- **Oran ayarı** — `adjustRate` ile hız değiştirilebilir; değişimden **önce** eski oranla biriken tutar `pendingClaim`'e dondurulur, yani hak ediş kaybolmaz.
- **Güvenli durdurma** — `pauseStream` alıcının o ana kadarki hak edişini rezerve eder, kalan bütçeyi işverene iade eder.
- **Acil çekim** — İşveren `EMERGENCY_DELAY` (24 saat) boyunca fon eklemediyse, alıcı `emergencyWithdraw` ile kalan bakiyeyi kurtarabilir.
- **Gelecek hak satışı** — Alıcı, gelecekteki belirli bir zaman dilimindeki talep hakkını `listFutureClaim` ile ilan eder; bir alıcı `buyFutureClaim` ile iskontolu satın alır. O pencere boyunca `claim` hakkı alıcıya geçer (anlık likidite).
- **Güvenlik** — Re-entrancy guard + Checks-Effects-Interactions deseni; ödemeler pull-payment mantığıyla yapılır.

## Kullanım Senaryoları

- **Freelance / uzaktan çalışma:** iş ilerledikçe ödeme akar, güven sorunu azalır.
- **Maaş ödemeleri:** çalışan ay sonunu beklemeden hak edişini çeker.
- **Abonelik & kiralama:** kullanım süresi kadar otomatik akan ödeme.
- **Vesting / hak ediş:** ekip ve yatırımcı tahsislerinin zamana yayılı dağıtımı.

---

## Mimari

Proje bir monorepo'dur: zincir üstü kontrat (Foundry) + istemci (Next.js).

```
.
├── src/StreamPay.sol        # Ana kontrat
├── test/StreamPay.t.sol     # Foundry testleri
├── script/
│   ├── Deploy.s.sol         # Deploy + deployments.json yazımı
│   └── Demo.s.sol           # Uçtan uca senaryo simülasyonu
├── foundry.toml             # Monad testnet RPC/chain ayarı
├── deployments.json         # Deploy edilen adres
└── streampay-app/           # Next.js arayüzü
    └── src/
        ├── app/             # /, /recipient, /employer, /about
        ├── components/      # NavBar, Footer, ConnectButton, NetworkBanner
        └── lib/             # wagmi config, contract (ABI+adres), formatlayıcılar
```

### Kontrat katmanı (`src/StreamPay.sol`)

Durum (state):

- `Stream` — `employer, recipient, ratePerMinute, lastClaimTimestamp, employerBalance, lastTopUpTimestamp, active`
- `ClaimRightSale` — `streamId, startTime, endTime, originalRecipient, buyer, active`
- Eşlemeler: `streams`, `claimSales`, `pendingClaim` (rezerve edilen hak ediş), `salePrice` (ilan fiyatı)

Temel fonksiyonlar:

| Fonksiyon | Çağıran | Görev |
|---|---|---|
| `createStream` | İşveren | Akış açar, bütçeyi kilitler |
| `claimableAmount` (view) | Herkes | Şu an birikmiş tutarı hesaplar |
| `claim` | Alıcı / satış penceresinde buyer | Biriken tutarı öder |
| `adjustRate` | İşveren | Oranı değiştirir (önce birikim dondurulur) |
| `pauseStream` | İşveren | Durdurur; hak edişi rezerve eder, kalanı iade eder |
| `emergencyWithdraw` | Alıcı | Terk edilmiş akıştan kalan fonu kurtarır |
| `withdrawPending` | Alıcı | Rezerve edilmiş (`pendingClaim`) tutarı çeker |
| `listFutureClaim` / `buyFutureClaim` | Alıcı / buyer | Gelecek talep hakkının satışı |

**Hesap mantığı:** Oran dakika bazlıdır; birikim saniye bazında orantılıdır:
`accrued = (block.timestamp − lastClaimTimestamp) × ratePerMinute / 60`, üst sınır `employerBalance`.

### İstemci katmanı (`streampay-app/`)

- **Next.js (App Router) + TypeScript**, **wagmi + viem** ile zincir etkileşimi, **TanStack Query** ile veri yönetimi, **Tailwind CSS** ile stil.
- Sayfalar: `/` (tanıtım), `/recipient` (alıcı paneli — canlı talep sayacı), `/employer` (işveren paneli — akış oluştur/yönet), `/about` (detaylı anlatım).
- Uygulama bağımsızdır: ABI ve deploy adresi `src/lib/contract.ts` içine gömülüdür, bu yüzden Foundry derleme çıktısına ihtiyaç duymadan ayrı dağıtılabilir.

---

## Kurulum

Gereksinimler: [Foundry](https://book.getfoundry.sh/) ve Node.js 18+.

```bash
# Kontrat
forge install
forge build
forge test            # testleri çalıştır

# Arayüz
cd streampay-app
npm install
npm run dev           # http://localhost:3000
```

Deploy için kök dizinde `.env` oluştur (`.env.example`'ı kopyala):

```bash
forge script script/Deploy.s.sol --rpc-url $MONAD_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

---

## Yol Haritası

Uzun vadeli hedef, ödeme akışlarını üzerine finansal ürünler kurulabilecek bir
temel katmana dönüştürmek:

- **DeFi teminatı** — Aktif bir akışı (öngörülebilir gelecek nakit akışı) teminat olarak kilitleyip kredi çekmek.
- **Akış devri** — Bir akışın tamamının başka adrese kalıcı transferi; ikincil piyasada alınıp satılabilen alacaklar.
- **Kredi & faktoring** — Gelecek hak satışı üzerine kurulu, akış bazlı teminatlı borç verme havuzları.
- **ERC-20 & çoklu varlık** — Yalnızca yerel MON değil, token bazlı akışlar; bordro, abonelik ve vesting senaryoları.

---

## Lisans

MIT

Built by [@ex_machinam](https://x.com/ex_machinam)
