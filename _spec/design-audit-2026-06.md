# REACH — F2P Tasarım Denetimi (Haziran 2026)

> Senior Game Designer + LiveOps Director + Mobile F2P Consultant perspektifiyle,
> 6 ajanlı bir denetim turunun sentezi: kod tabanı satır satır okundu (gerçek
> sayılar), 13 rakip oyun araştırıldı (Royal Match, Match Factory!, Block Blast,
> Zen Match, Number Match, Sudoku.com, NYT/Wordle, Two Dots, Vita Mahjong...),
> 4 acımasız alan eleştirmeni (Zen / Daily / Para / Meta) çalıştırıldı.
> Ham çıktı: workflow `wf_c4851b80-43f`.

---

## Yönetici Özeti

**Çekirdek mükemmel, üstü boş.** Solvable-by-construction üretici, deterministik
Daily, Wordle-kalite paylaşım, sakin marka — hepsi gerçek varlık. Ama:

1. **Zen, 20 tahtalık bir demo + sonsuz koşu bandı.** Merdiven ~30-60 dakikada
   tükenir; level 20+ sonrası her tahta parametre-aynıdır (6×6, 1-9, decoy 8-24).
   Level sayısı yalan söylüyor: `clearsPerLevel=1` iken ana ekran çubuğu %10'luk
   bölümler gösteriyor — aynı kartta iki çelişik kurgu.
2. **Daily, retention boşluğuna sarılmış sağlam bir iskelet.** 3 dakikada bitiyor,
   sonrası yok: takvim yok, arşiv yok, bildirim yok. En kötüsü: **streak sessizce
   ve "sahnede" ölüyor** — gün kaçıran oyuncu ana ekranda eski 🔥5'i görmeye devam
   ediyor, bir sonraki oyunda gözünün önünde 1'e çöküyor. (Gerçek bug + en büyük
   churn anı.)
3. **Ekonomi placeholder.** Musluk/gider oranı ~6:1 (+118 net coin/gün vs TOPLAM
   800 coinlik kalıcı gider — 7. günde her şey alınmış). Ödüllü reklam (+25) tek
   tüketilebilir giderden (ipucu -20) fazla ödüyor → her ipucu kalıcı olarak
   bedava → coin paketi dönüşümü ~%0. Paket eğrisi de düpedüz hatalı:
   orta paket EN KÖTÜ değer (252→234→286 c/$). Premium $3.99'da üçlü
   kanibalizasyon (reklamsız + sınırsız ipucu + tüm temalar) → en iyi müşterinin
   LTV tavanı $3.99. Tahmini ARPDAU ~$0.02 vs $0.15-0.50 sektör bandı.
4. **Giriş ekranı statik poster.** 200. oturum 2. oturumla piksel-aynı. Coin ana
   ekranda görünmüyor, shop iki ekran derinde gömülü, geri-dönme tetikleyicisi
   sıfır. `DailyRecord.results` (gün-gün yıldız/ipucu) yazılıyor ama **hiçbir
   ekran okumuyor** (grep-doğrulandı).

**Tek doğrulama:** Tek para birimi (coin) DOĞRU karar. İkinci bir "elmas" eklemek
fiyat opaklığı (dark pattern) katar, hiçbir sorunu çözmez. Coinin ihtiyacı kardeş
değil, **yapacak iş**.

---

## 1. Zen Mode

### Güçlü
- Solvable-by-construction + seed + decoy-band'lı `generateTuned`: sonsuz, sıfır
  marjinal maliyetli, çözülemez-tahta riski olmayan içerik. Sonsuz modun en zor
  mühendislik problemi zaten çözülmüş.
- İlk ~20 tahta iyi temposluymuş onboarding (tek eksen birden hareket ediyor).
- Can yok, timer yok, sınırsız undo — Block Blast'ın (70M DAU, ~%26 D1) kanıtladığı
  sakin-sonsuz şekille yapısal ikiz.

### Zayıf (acımasız)
- Merdiven 20. tahtada bitiyor; tüm cap'ler ~level 32'de bağlanıyor. Sonrası
  sonsuza dek aynı konfig.
- Merdivende terminal REGRESYON: groupMax 14-19 arası 3-5 iken 20+ seviyede 2-4'e
  geri düşüyor; kalan tek kol decoy yoğunluğu — yanlış iz cezasız olduğu için bu
  da bahissiz bir zaman vergisi.
- "Level" anlamsız enflasyon: tahta başına +1. 100. tahtada "Level 101".
- Oturum kavisi yok: skor yok, zincir yok, hedef yok, event yok. Kovalanacak,
  korunacak, tamamlanacak hiçbir şey yok.
- Düz ekonomi: 12 hücreli tahta da 36 hücreli 24-decoy'lu tahta da +12 coin.
- Motor, türün uzun-vadeli çeşitlilik playbook'unun TAMAMINI ifade edemiyor
  (engel/kilitli taş, özel taş, çoklu hedef, düzensiz grid, yerçekimi).

### Öneriler (özet; detay §7'de)
- Z1. **Görünmez zorluk direktörü** (Block Blast "God Mode" uyarlaması) — decoy
  bandını oyuncu performansına göre sessizce kaydır. Low effort.
- Z2. **Flow chain + ustalık istatistikleri** — temiz seri zinciri, kademe coin
  bonusu, ZenRecord'u tek int'ten istatistik bloğuna büyüt. Low effort.
- Z3. **Bölümler (chapter) + testere-dişi tempo + işaretli zor final**
  (`clearsPerLevel=10`, çubukla bar nihayet anlaşır; final çift coin; bölüm sandığı).
- Z4. **Modifier taşlar** (post-construction süsleme: örtülü "?", altın, bağlı
  kilit, joker) — solvability'ye dokunmadan bölüm başına tek tip aç.
- Z5. **7 günlük mozaik-açma sezonu + kalıcı galeri** (Block Blast Adventure'ın
  galeri eksikliği giderilmiş hali).
- Z6. **Motor uzantısı: boşluk-hücreli siluet tahtalar + çift hedefli finaller**
  — tek motor-dokunuşlu öneri; en sona.

---

## 2. Daily

### Güçlü
- Deterministik `dailySeed` → sıfır backend'le küresel aynı tahta; **arşiv
  matematiksel olarak zaten var** (bedava içerik).
- `dateKey → DailyResult` haritası, Sudoku.com tarzı takvim/madalya sisteminin
  veri katmanını %80 hazır etmiş.
- Paylaşım formatı gerçekten Wordle-kalite; Daily'de reklam yok (doğru).
- 42 coin/gün ile ekonominin en iyi musluğu zaten Daily'de.

### Zayıf (acımasız)
- Günde tek orta-zorluk tahta, sonra ölü uç. NYT verisi: 2+ günlük alışkanlık
  noktası olan kullanıcılar en az churn ediyor; REACH'te 1 nokta, ~3 dakika.
- **Streak sessiz ceza + bayat-gösterim bug'ı**: reset ancak SONRAKİ tamamlamada
  hesaplanıyor; ana kart o zamana dek eski sayıyı gösteriyor. Dondurma yok,
  tamir yok, af yok.
- Herkese sonsuza dek `Difficulty.medium`: 1. gün oyuncusuna fazla zor
  (Zen 9-13 bandı içeriği), level-20+ oyuncusuna trivial.
- Takvim yok, madalya yok, arşiv yok, bildirim yok; `kShareUrl` boş (paylaşım
  döngüsü hiçbir yere varmıyor).
- Saat oynatma 42 coin + streak çiftçiliğine açık (recordCompletion'da sanity
  guard yok).

### Öneriler
- D1. **Streak Freeze (150c, max 2) + 48s Repair (60c veya 1 ödüllü reklam,
  ayda 1) + bayat-gösterim düzeltmesi.** Denetimin tek başına en yüksek D7
  kaldıracı + ilk tekrarlayan coin gideri.
- D2. **Aylık takvim + madalyalar** (altın=her gün, gümüş=25+, bronz=20+;
  kaçan gün 40 coin'e arşivden telafi — streak'e sayılmaz). En büyük D30 kolu.
- D3. **Daily Ladder: aynı tarihten 3 katman** (Easy 4×4 / Medium=streak+paylaşım
  tahtası / Hard 6×6 +20 bonus). Oturum 3→8-10 dk.
- D4. **Premium Arşiv + istatistik ekranı** (ücretsiz: son 7 gün; Premium: tamamı).
  NYT'nin $4.99/ay ile sattığı şey; Premium'a ilk retention-değeri.
- D5. **Sakin bildirim stratejisi** (sadece 2 tetik: "bugünün tahtası hazır"
  [3. Daily'den sonra izin iste] + 20:00 streak-riski [streak≥3 iken]; günde max 1).
- D6. **Paylaşım döngüsünü kapat + gün-sınırı sertleştir** (kShareUrl, milestone
  paylaşım istemleri [7/30/100], saat-geri-alma koruması).

---

## 3. Giriş Ekranı

### Zayıf (acımasız)
- Streak 0 iken (her yeni oyuncu) ve Daily bittiğinde: başlık + 2 kart + dişli.
  Geri dönme nedeni gösterilmiyor — geri sayım yok, takvim yok, hedef yok.
- Coin ana ekranda YOK; shop yalnızca oyun-içi chip ve ayarlardan ulaşılır.
  Triple Match 3D No-Ads SKU'sunu level 5'ten itibaren kalıcı gösterir; bizim en
  iyi SKU (premium) iki ekran derinde.
- Level rozeti + %10 bar çelişkisi (yuk. Zen).

### Öneriler
- H1. **Durum şeridi**: coin chip (hazır widget zaten var, kullanılmıyor) +
  her zaman görünen streak alevi (0'da gri — kanca 1. oturumda kurulsun) + dişli;
  Zen kartı altına ince Shop satırı (premium görünür). Mono/ink tonlarda, rozetsiz,
  pulsesız — poster estetiği korunur.
- H2. Daily bitince kartta **"sonraki bulmaca HH:MM" geri sayımı**; karta dokunuş
  takvimi açar.
- H3. Zen kartında dürüst **bölüm** gösterimi (Z3 ile).

---

## 4. Monetization & Ekonomi

### Matematik (mevcut, gerçek sayılarla)
- Kaynaklar: başlangıç 60 · clear +12 · Daily bonus +30 · ödüllü reklam +25 ·
  paketler 250/$0.99, 700/$2.99, 2000/$6.99.
- Giderler: ipucu -20 · temalar 150/250/400 (TOPLAM 800, tek seferlik).
- Mütevazı günlük oyuncu (1 Daily + 8 Zen): +138/gün, net +118. 7. gün ≈ 886 coin
  → katalog bitti. Cüzdan artık amaçsız bir sayaç.
- **Arbitraj**: 1 reklam (+25) > 1 ipucu (-20) → ipuçları kalıcı bedava → 2000
  coinlik paket = 100 ipucu = kimsenin asla ihtiyacı olmayan şey.
- **Paket eğrisi bug'ı**: 252.5 → 234.1 → 286.1 c/$ (orta paket en kötü; standart
  çapanın tersi).
- **Premium $3.99 = üçlü kanibalizasyon**: Sudoku.com yalnız reklamsızlığı ~$15'e
  satıyor; biz reklamsızlık + sınırsız ipucu + tüm temaları yarı fiyata verip
  müşteriyi tüm gelir şeritlerinden siliyoruz.
- Tahmini ARPDAU ~$0.02 (≈1.14 interstitial/gün × ~$12 eCPM + ~0 IAP) vs
  $0.15-0.50 hibrit-casual bandı.

### Öneriler
- M1. **Premium'u ayrıştır ve yeniden fiyatla**: $7.99 (test $6.99-9.99);
  reklamsız + günde 5 bedava ipucu (sınırsız değil) + tüm temalar. Tek günlük en
  büyük gelir kolu, ~1 gün iş.
- M2. **Reklam düzeltmeleri**: ödüllü 25→15 (ya da ipucu-funnel'da reklam doğrudan
  ipucu versin); kazanım ekranına **coin ikileme** ödüllü butonu (türün en yüksek
  doluluk/en düşük küskünlük yerleşimi — bizde hiç yok); günde 1 hediye reklamı
  (+40); **ilk interstitial 12 clear'dan önce asla** (Vita Mahjong kuralı).
- M3. **Streak Freeze/Repair** (D1 ile aynı — duygusal ağırlıklı ilk gerçek gider).
- M4. **Kozmetik derinlik**: 4→12 palet (artan fiyat eğrisi), 4 iz-stili
  (trace-trail), ayda 1 sezonluk palet (gelecek yıl aynı ay geri döner — yumuşak
  kıtlık, FOMO sayacı yok). Katalog 800 → ~9.000 coin ≈ 2,5 ay oyun. **Tüm IAP
  önerilerinin ön şartı bu** — gider yoksa hiçbir coin SKU'su satmaz.
- M5. **Kil Kavanoz (piggy bank, sakin sürüm)**: her clear kavanoza +5 BONUS coin
  (cap 600); dolunca $2.99'a açılır; asla modal, asla sallanmaz, asla süresi
  dolmaz. Royal Match Endless Treasure'ın (+12-20% gelir) basınçsız hali —
  fail-state'i olmayan oyunda mevcut TEK tekrarlanabilir orta-katman IAP şekli.
- M6. **Paket eğrisini onar + Starter Pack**: 200/$0.99 → 800/$2.99 (popüler) →
  2200/$6.99 (en iyi değer); $1.99 tek seferlik başlangıç paketi (500 coin +
  coinle alınamayan "ember" palet + 1 Freeze) — 3. Daily'den sonra bir kez
  gösterilir, sonra sessizce rafta.
- M7. **Aylık kupa takvimi + Premium Arşiv** (D2+D4 ile aynı sistem — Premium'un
  "sevdiğin şeyin fazlası" değeri).

---

## 5. Progression / Meta

- Kalıcı durum bugün: streak, boardsCleared (tek int!), coins, temalar,
  gün-başına yıldız (hiç gösterilmiyor). Birikimli emeği kutlayan SIFIR şey:
  temiz clear'lar sayılmıyor, longestStreak görünmüyor, toplam yıldız yok.
- P1. **Sessiz kilometre taşları**: ~15 kelimesiz rozet (toplam clear 50/250/1000,
  temiz clear 10/50/200, 3★ Daily 5/25/100, streak 7/30/100...); ödül anı yalnız
  kazanım ekranında, popup yok, kırmızı nokta yok.
- P2. **Atlas** (Z3'ün parçası): bölüm taşlarından dikey sakin patika; 5 bölümde
  bir glif rozeti. Görev listesi DEĞİL — görsel kayıt.
- P3. **Prestij paletleri**: satın ALINAMAZ — aylık kupa ve 5-bölüm kilometre
  taşlarından. (Kozmetiğin paraya indirgenmesini engeller.)
- P4. **Yıl sonu özeti** (NYT "Year in Games" deseni) — ileri tarih.

---

## 6. Rekabet Analizi — Çalınacak Dersler

| Oyun | Ders |
|---|---|
| **Block Blast!** (70M DAU) | En yakın yapısal ikiz. Çal: gizli merhamet algoritması, 7-günlük resim-açma etkinliği, ölçülü reklam yerleşimi (revive-only rewarded). |
| **Royal Match** | Ölçülmüş event rotasyonu (Pass +%31, piggy +%20); "Hard" etiketi zorluğu adil hissettirir; 3-galibiyet hediyesi. Üzüntü-maskotu baskısını ALMA. |
| **Sudoku.com / Number Match** (Easybrain) | Sayı-bulmaca retention iskeleti: günlük takvim → aylık kupa → sezonluk kupalar. Number Match'in "satır ekle" kurtarışı = bizim coin/reklam-fiyatlı kurtarma kalıbımız. Sudoku'nun zaafı (reklam küskünlüğü) bizim pozisyonlanma boşluğumuz. |
| **NYT/Wordle** | Günde-tek kıtlık + streak + paylaşım = ritüel. Çoklu günlük alışkanlık noktası olan kullanıcı churn etmiyor. Arşiv+istatistik satılabilir premium içerik. |
| **Match Factory!** | Reklamsız IAP-first sakin oyun mümkün. Ders: bedava booster arzını kıs — bizim 25>20 arbitrajının tam tersi. |
| **Zen Match** | Dekorasyon/görsel meta, sakin oyunun doğru coin gideri. Uyarı: "sakin" tek başına hendek değil; live-ops'ta geride kalan ilk hamleci satın alındı ve geriledi. |
| **Two Dots** | Elle üretilmiş event içeriği sürdürülemez (2025'te kapattılar) → bizim eventler PROSEDÜREL beslenmeli. "Rewind" (kaçanı telafi) kalıbı sakin markaya cuk oturur. |
| **Vita Mahjong** ($55M/yıl reklam) | İlk interstitial'ı oyuncu yatırım yapana dek geciktir (level ~11); feature sprawl yerine zorluk ayarına yatır. |
| **Triple Match 3D** | No-Ads/starter teklifini erken tanıt, kalıcı görünür tut; teklif baskısını coin bakiyesi tükenişine endeksle (bizde nazik versiyonu). |

**Bizde eksik olup türde standart olanlar:** günlük takvim/kupa, streak koruması,
kazanım-sonrası ödüllü ikileme, starter pack, piggy bank, kozmetik katalog
derinliği, herhangi bir event, herhangi bir birikimli istatistik gösterimi.

---

## 7. Önceliklendirme

### HIGH IMPACT / LOW EFFORT (önce bunlar — çoğu config + UI)
| # | Öneri | Retention | Monetization | Maliyet | Risk |
|---|---|---|---|---|---|
| 1 | Streak Freeze+Repair + bayat-gösterim fix (D1/M3) | **En büyük D7 deltası**; ilk kırılma anını savunur | İlk tekrarlayan coin gideri (200-300c/olay) | 1-2 gün; DailyRecord+2 alan | Aşırı cömertlik streak'i sulandırır → sıkı cap |
| 2 | Ana ekran reworku (H1-H2: coin chip, daimi alev, shop girişi, geri sayım) | D1 kancası 1. oturumda; tüm diğer önerilerin giriş kapısı | Premium görünürlüğü = en büyük dönüşüm kolu | ~150 satır, sadece home_screen | F2P lobi karmaşası → mono/ink, rozetsiz |
| 3 | Reklam onarımı (M2: 25→15, kazanç-ikileme, hediye reklamı, ilk-interstitial≥12) | D1 +1-2pt (ilk oturumda reklam yok) | Rewarded imp/DAU ~0.3→1.5-2.5; arbitraj kapanır | 2-3 gün, GameConfig+2 buton | İkileme butonu sade kalmalı; gider gelmeden kısma |
| 4 | Premium $7.99 + 5 ipucu/gün (M1) | Nötr-pozitif | LTV tavanı 2×; gelecek SKU'lar yaşar | ~1 gün | Dönüşüm oranı testi (pre-launch = bedava test) |
| 5 | Görünmez zorluk direktörü (Z1) | Erken D1/D7; stuck-frustrasyonu emer | Dolaylı | Küçük; controller-yanı matematik | Yetenekliye fazla kolaylaştırma → 1 band adımı cap |
| 6 | Flow chain + Zen istatistikleri (Z2) | "Bir tahta daha" + D30 ustalık döngüsü | Chain-shield: yeni opsiyonel gider + reklam yeri | Küçük; record+UI | Zincir kırılması tüy gibi olmalı |
| 7 | Bildirimler (D5: 2 tetik, cap'li) | Sessiz streak ölümünü bitirir; standart D7 savunması | Dolaylı | 1-2 gün | Yorgunluk = marka zehri → cap pazarlıksız |
| 8 | Paket eğrisi + Starter Pack (M6) | Hafif | %0 → %1-3 ilk-satın-alma | 2-3 gün | Giderlerden (M4) önce çıkma |
| 9 | Rozet rafı (P1) | D30+ uzun ufuk | İhmal edilebilir | Küçük; 1 yeni record | Rozet enflasyonu → ~15 cap |
| 10 | Paylaşım döngüsü + saat koruması (D6) | Bileşik organik edinim | Dolaylı | 1-3 gün | Milestone-dışı istem = spam |

### HIGH IMPACT / MEDIUM EFFORT (retention iskeleti + içerik)
| # | Öneri | Retention | Monetization | Maliyet | Risk |
|---|---|---|---|---|---|
| 11 | Aylık takvim + madalya (+telafi 40c) (D2/M7) | **En büyük D30 kolu**; streak kırılsa da "gümüş hâlâ mümkün" | 2. tekrarlayan gider; oturum sayısı ↑ | 2-4 gün; saf view (veri hazır) | Telafi "günü gününde" değerini sulandırmasın |
| 12 | Zen bölümleri + sawtooth + dürüst level (Z3/H3) | Oturum-sonu hedefi; level-32 uçurumuna saldırı | Final 2×, doğal interstitial yeri, starter-pack anı | difficulty remap + UI; motor 0 | Level yeniden-tabanlama testlerle |
| 13 | Daily Ladder 3 katman (D3) | Oturum 3→8-10dk; D7 "merdiveni bitir" | 3× ipucu anı | 3-5 gün; persistence migration şart | #N/paylaşım saflığı Medium'da kalmalı |
| 14 | Kozmetik derinlik: 12 palet + iz stilleri + sezonluk (M4) | Cüzdana amaç = hedef gradyanı | **Tüm IAP'lerin ön şartı**; katalog 800→9.000c | 1-1,5 hafta (sanat dahil) | Solo-dev sanat bandı; CVD kontrolü her palet |
| 15 | Modifier taşlar (Z4) | Bölüm başına yenilik saati sıfırlanır — ana D7/D30 Zen kolu | İlk gerçek ipucu talebi; altın taş = ayarlı musluk | Tile+üretici post-pass+UI; solver dokunulmaz | Kilit-sıralama doğrulaması hatasızsa OK; stress suite şart |
| 16 | Mozaik sezonu + galeri (Z5/P) | D7 omurgası + D30 koleksiyon; Daily ile habit-stack | Rewind coin'le; Premium +1 hücre | Yeni record+controller+~400 satır; motor 0 | Prosedürel sanat kalitesi = kill-risk; önce prototip |
| 17 | Premium Arşiv + istatistik (D4) | D30 + lapsed-dönüş ("birikmiş içerik") | Premium'a içerik değeri; ileride abonelik yolu | 3-4 gün | Arşiv bugünün aciliyetini yemesin (yarım coin, streak yok) |
| 18 | Kil Kavanoz piggy bank (M5) | Hafif oturum hedefi | Eksik $2.99 tekrarlanabilir IAP | ~1 hafta; ilk consumable akış | "Rehin coin" algısı → daima BONUS olarak çerçevele |

### HIGH IMPACT / HIGH EFFORT (yıl-1 derinliği; lansmanı BLOKLAMASIN)
| # | Öneri | Retention | Monetization | Maliyet | Risk |
|---|---|---|---|---|---|
| 19 | Motor uzantısı: boşluk-hücreli siluetler + çift-hedefli finaller (Z6) | D30/uzun kuyruk; uzman bilişsel görevi değişir | Dolaylı (final 2×, ipucu talebi) | Grid+carver+solver+decoy metriği+15k stress rerun | Setin en yüksek regresyon riski; P11-16 kanıtlanmadan başlama |

---

## Önerilen Sıra (faz planı)

- **Faz 1 — Ekonomi onarımı (lansman öncesi şart):** #3 reklam onarımı → #4
  premium → #8 paket eğrisi → #14 kozmetik katalog. (Gider olmadan hiçbir şey
  satılmaz; arbitraj kapanmadan paket ölü.)
- **Faz 2 — Retention iskeleti:** #1 freeze/repair → #2 ana ekran → #11 takvim
  → #7 bildirim → #5-6 Zen yumuşatma → #10 paylaşım.
- **Faz 3 — İçerik derinliği:** #12 bölümler → #15 modifier taşlar → #13 ladder
  → #16 mozaik → #17 arşiv → #18 kavanoz → #9 rozetler.
- **Faz 4 — Yıl-1:** #19 motor uzantısı, yıl-sonu özeti, hafif leaderboard.

## Mimari Notu

- Önerilerin ~%85'i **motor dışı** (controller + record + UI): mevcut
  record/Riverpod/remote-config desenleri tam da bu şekiller için kurulmuş.
- Deterministik seed'ler (gün/hafta) takvim-arşiv-mozaik-sezonu **bedava içerik**
  yapar — bu kod tabanının gizli süper gücü.
- Motorun bugünkü sınırı (engel/özel taş/çoklu hedef/düzensiz grid yok) yalnız
  #15 (post-construction süslemeyle sınırı aşmadan) ve #19'da (gerçek uzantı)
  devreye girer. Solvability-by-construction her ikisinde de korunur.
- Streak/tarih mantığı (DailyController) kod tabanının en hassas yeri — #1, #11,
  #13, #17 hepsi ona dokunur; recordCompletion'ın idempotent tek-kapı düzeni
  korunmalı, her değişiklik birim testle.
