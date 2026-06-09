# REACH — Geliştirme Günlüğü (DEVLOG)

> Bu dosya, REACH'i sıfırdan bu noktaya getirirken **ne yaptığımızı ve neden öyle karar verdiğimizi** kaydeder. Karar gerekçeleri özellikle önemli — birçok kez bilinçli olarak yön değiştirdik. (Kullanıcıya dönük teknik kurulum dokümanı için bkz. `README.md`.)
>
> Çalışma başlığı: **REACH**. Bundle id (placeholder): `com.reach.reach`.

---

## 1. Oyun nedir (GÜNCEL hâli)

Sakin, **dil-bağımsız** bir sayı bulmacası — kelime-bulmacanın sayısal versiyonu.

- R×C tahta sayılarla dolu, üstte tek bir **hedef** sayı.
- Oyuncu **parmakla bitişik sayıların üzerinden çizer**; izin toplamı hedefe **tam eşitse** o grup tatmin edici bir "pop" ile **temizlenir**. Eşit değilse hiçbir şey olmaz (ceza yok).
- Tüm tahtayı temizle = board tamamlandı → **yıldız** (verimlilik) + **clean** rozeti (ipucusuz) + **coin**.
- **No-fail**, yerçekimsiz, sürükle-çiz. **Peg-solitaire mantığı**: serbest oynarsın; başarısızlığı ancak **hiç hamle kalmadığında** (ayrık taşlar kaldığında) fark edersin → nazik "geri al / yeniden kur" pop-up'ı.
- **Modlar:** Daily (deterministik, streak, spoiler-free paylaşım) + Zen (sonsuz, seviyeyle artan zorluk).
- **Para:** coin ekonomisi (ipucu + tema sink'leri) + tek seferlik Premium + nazik reklamlar.

---

## 2. Teknik temel

- **Flutter (stable) + Dart**, state yönetimi **Riverpod**.
- **Saf-Dart engine** (`lib/engine/`) UI'dan tamamen ayrı → unit-test edilebilir, daily seed reproducible.
- **Çözülebilirlik construction ile garanti**: tahta, hepsi hedefe toplanan bağlı yollardan (partition) inşa edilir; aramayla değil.
- Deterministik PRNG (splitmix64) → Daily her cihazda aynı.
- Fontlar **bundled** (Fraunces + DM Mono), offline.
- Servisler arayüz arkasında, no-op/dev impl + gerçek impl: `StorageService`, `AdService`, `PurchaseService`, `AnalyticsService`, `RemoteConfigService`.

---

## 3. Yolculuk & kararlar (neyi NEDEN yaptık)

### 3.1 Başlangıç — spec'e göre MVP
İlk spec bir **merge** oyunuydu (iki bitişik taşı birleştir, hedefe *tam* otur, *overshoot* yumuşak hata, "par"=en az hamle). 1D prototipten 2D'ye genelleme.
- Saf-Dart engine + tam UI kuruldu; **stress test 60k+ board** (her tier 20k) sıfır hatayla çözülebilir + non-degenerate.
- iOS simülatöründe çalıştı; tema/font/etkileşim doğrulandı.

### 3.2 PİVOT → "Toplam Avı" (find-and-clear)
**Neden:** Hedef kitle = telefonda **kelime-bulmaca** oynayan orta yaş/rahat kişiler. Eski "birleştir + optimize et (par, overshoot)" mekaniği bu kitle için fazla **optimizasyon-ağırlıklı** ve gerilimliydi. Kelime-bulmacanın hazzı: **tara → tanı → bul → temizle**.
**Karar:** Mekaniği "bitişik grupları bul, tahtayı temizle"ye çevirdik. **Overshoot tamamen kalktı.** Engine yeniden yazıldı; yeni garanti: *"her tahta tamamen temizlenebilir"* (yine construction'la). Stress test buna göre güncellendi.

### 3.3 Seçim biçimi → sürükle-çiz
Kitleye en tanıdık olan **parmakla çizme** (kelime-bulmaca gibi). İzin başında canlı **toplam çipi** akar; release'te submit.

### 3.4 Çıkmaz (dead-end) sağası — en çok tartıştığımız konu
Üç aşamadan geçti, her seferinde **kullanıcının canlı playtest geri bildirimiyle** yön değişti:
1. **Bounce (reddet):** Geçerli ama tahtayı çözümsüz bırakan yolu sessizce reddet. → Sorun: "12 yaptım, neden temizlenmedi?" kafa karışıklığı + sırayla deneyip geçilebilir (brute-force) → ipucu değeri sıfır.
2. **Açık çıkmaz uyarısı:** Her geçerli yol temizlenir; strand olunca açık pop-up. → Hâlâ erken/anlık uyarı veriyordu.
3. **PEG-SOLITAIRE (final):** Anlık uyarı **yok**. Her geçerli yol temizlenir (net feedback). Başarısızlık ancak **hiç hamle kalmadığında** (ayrık taşlar) ortaya çıkar → nazik **"geri al / yeniden kur"** pop-up'ı. Başarısızlığı sonda keşfetme = oyunun asıl becerisi ("kenardan içe gidip ayrık taş bırakma").
- **İpucu = çıkmaza sokmayan GÜVENLİ hamle** gösterir (partition solver). Değeri: "kendimi köşeye sıkıştırmayayım."
- **Geri-al sınırsız** (sakin kitleye ceza yok). Brute-force'u **zorluk/decoy** engeller, undo limiti değil.

### 3.5 Monetizasyon — coin mi, video→ipucu mu?
- Kitle basitliği + "para makinesini doğrulamadan kurma" → ilk eğilim **video→ipucu (direkt)**.
- Ama kullanıcı netleştirdi: **"kur-ve-unut değil, ciddi yatırım"** + "sonu coine dönecekse şimdi çıkalım." → **Coin ekonomisi şimdi** kuruldu.
- **UX görünmez/tek-dokunuş:** ipucuna bas → coin yetiyorsa sessiz harcanır; yetmezse arka planda **reklam→coin→ipucu** zinciri kendiliğinden döner. Kullanıcı "elmas yönetimi" yapmaz. Premium → ipucu bedava.
- **İlke:** coin asla ilerlemeyi kilitlemez (sadece opsiyonel ipucu/kozmetik). Cömert + **remote-config ile ayarlanabilir**.

### 3.6 Yıldız + clean rozeti
Her board: **1–3 yıldız = verimlilik** (yanlış/iz sayısı). İpucu yıldızı düşürmez → ipucu satışı caydırılmaz. **Clean rozeti** = ipucusuz bitirme. Gate değil, ustalık/kozmetik amaçlı.

### 3.7 Decoy-zorluk eğrisi
**Decoy** = hedefe toplanan ama çözümün parçası olmayan "yanlış yol". Bunlar zorluğun ve **ipucu talebinin motoru**. Generator her tahtayı, **seviyeyle yükselen** bir decoy bandına yönlendirir (`generateTuned`). Erken seviye az decoy (sakin), ileri seviye yoğun (zor → "göremiyorum → ipucu"). Bounce/çıkmaz güvenliği bunu güvenli kılar. **Çarpma/basamak yok** — zorluk: tahta boyutu + grup sayısı/boyutu + hedef + decoy yoğunluğu.

### 3.8 Shop (Gemini'nin iyi fikriyle genişletildi)
- Coin paketleri (IAP, consumable) + Premium (Unlock/Restore) + **coin'le açılabilen temalar** (Premium hepsini açar) + video-izle-coin.
- **Coin'in artık 2 sink'i var** (ipucu + kozmetik) → biriktirme motivasyonu.

### 3.9 Altyapı
- **Analytics** (`AnalyticsService`): board/clear/hint/ad/coin/purchase/daily olayları; dev'de konsola loglar, gerçek sağlayıcı (Firebase vb.) için seam.
- **Remote config** (`RemoteConfigService` + `GameConfig`): coin/reklam/yıldız parametreleri tek yerde, **lansman sonrası rebuild'siz** ayarlanabilir.

### 3.10 Doğrulama disiplini
- Her aşamada `dart analyze` temiz + `flutter test` yeşil + iOS simülatöründe canlı doğrulama.
- İki kez **adversarial review workflow** (çok-ajanlı): engine audit + app-layer review. Gerçek bug'lar yakalandı (örn. undo'nun win-recorded flag'ini sıfırlamaması, `DailyResult.fromMap` null-coalesce eksiği, zen ladder'ın stress-test kapsamı dışı kalması) → hepsi düzeltildi + regresyon testi eklendi.
- Not: bu ortamda `flutter analyze` çöküyor → `dart analyze lib test` kullanıyoruz.

---

## 4. Mimari (dosya haritası)

```
lib/
  config/         app_constants, ad_config, iap_config, service_config, remote_config(GameConfig)
  engine/         SAF DART — UI yok
    models/       tile, grid, puzzle, game_state
    rng.dart      splitmix64 (cross-device deterministik)
    difficulty.dart  tier'lar + endlessForLevel (sonsuz ramp) + decoy bandı
    generator.dart   generate (partition inşa) + generateTuned (decoy bandına yönlendir)
    solver.dart   isCleared, hasMove (ucuz "hamle var mı"), findPartition (güvenli ipucu),
                  countTargetPaths (decoy metriği)
  services/       storage(+prefs/inmemory), ad(dev/google), purchase(dev/store),
                  analytics(noop/debug), remote_config(local), persisted_models
  game/
    state/        Riverpod: game/daily/zen/wallet/settings/entitlement controller + providers
    theme/        palette (coin fiyatlı), app_text (Fraunces/DM Mono)
    widgets/      board(drag-trace), tile, coin_chip, control_bar, win_sheet, onboarding,
                  paper_background, soft_button, pressable
    screens/      home, game, settings, shop
    share_text.dart
  main.dart       servisleri kurar + ProviderScope override
test/             engine (stress + solver + game_state + generator), state (controller + shop),
                  services (persisted_models), widget (drag→clear→win)
```

---

## 5. Kararlaştırılan ilkeler (değişmezler)

- **No-fail, sakin, dil-bağımsız** (çekirdek oynanışta kelime yok).
- **Çözülebilirlik construction-garantili** (asla çözülemez tahta üretilmez).
- **Monetizasyon ilerlemeyi gate'lemez** — sadece opsiyonel yardım (ipucu) + kozmetik.
- **Zorluk = decoy + tahta boyutu + grup boyutu + hedef** (çarpma/çok-basamak DEĞİL).
- **Para modeli = yumuşak/hacim-temelli** (Wordscapes modeli), Candy-Crush sert-fail değil.
- **Geri-al sınırsız**; çıkmaz sessiz değil, açık ama nazik.
- **Renk körü dostu (colourblind-safe):** durum renkle DEĞİL şekil/hareketle de belirtilir — seçili taş yükselir, match'te **✓**, ipucunda halka, üstte gerçek sayıyı gösteren toplam çipi. Ayarlardaki *Colourblind marks* ✓'yı belirginleştirir + reddedilen trace'e **✕** ekler. "Dil-bağımsız + renk-körü-dostu" hem vizyon hem pazarlama değeri.

---

## 6. Stratejik notlar (dürüst)

- **Asıl tıkaç dağıtım.** Reklam bütçesi var; ama paralı-UA'lı F2P "kur-ve-unut" değildir (ASO, reklam mediation, SDK/politika güncellemeleri, kampanya yönetimi sürekli ilgi ister).
- **Para yumuşaktır:** öncelik **retention × hacim × yumuşak reklam/IAP**. Sert fail eklemek bu kitlede churn → toplam geliri düşürür. Yani sakin model = bu kitlede geliri maksimize eden model.
- **Reklam parası harcamadan önce** D1/D7 retention'ı ölç (analytics bunun için kondu).
- Coin/fiyat dengeleri (aşağıdaki varsayılanlar) **tahmini** — analytics gelince remote-config ile ayarlanacak.

### Mevcut ekonomi varsayılanları (`GameConfig`, remote-config ile değişir)
- Başlangıç coin: **60** · İpucu: **20** · Board temizleme: **+12** · Reklam başına: **+25** · Daily bonus: **+30** · Interstitial: her **7** Zen temizleme · Yıldız: 0 yanlış=3, ≤2=2, üstü=1.
- Tema fiyatları: Sage **150**, Dusk **250**, Ink **400** (Premium hepsini açar).
- IAP: Premium ~**$3.99**; coin paketleri 250 / 700 / 2000 (placeholder $0.99 / $2.99 / $6.99).

---

## 7. Mevcut durum

- **69 test geçiyor**, `dart analyze` temiz.
- Engine stress: tüm shipped config'lerde (3 tier + endless rung'ları, dedup) **15k board/config (~120k+ board)** çözülebilir + well-formed; ayrıca solver örneklemi (partition + güvenli ipucu).
- iOS simülatöründe sorunsuz çalışıyor (home, board, drag-clear, ipucu, win, shop, **ses**).
- **Ses:** SFX (clear/win/tap/invalid) + ambient pad — `assets/sounds/` içinde **sentezlenmiş WAV'lar** (`_spec/synth_sfx.py`), ayarlarda SFX + Music toggle.
- ⚠️ **Sadece iOS simülatöründe** doğrulandı — **Android testi bekliyor** (haptics / safe-area / ad-IAP SDK).
- **GitHub:** `github.com/utkuyuksel/reach` (`main`).
- Reklam/IAP id'leri **placeholder** (Google test ad id'leri + placeholder ürün id'leri).
- Branch: `build/reach-mvp` (lokal) → remote `main`.

### Sürümler (git tag)
- **v1.0** — MVP + bul-ve-temizle + günlük/zen + coin ekonomisi + **shop** (önceki GitHub baseline'ı).
- **v1.1** — **ses** (SFX + ambient), shop cilaları (tema önizleme / yetersiz-bakiye flash / haptik), **colourblind-safe by-default** (match'te her zaman ✓, toggle ✕ ekler), eski "merge" metinlerinin temizliği, README'nin güncel ürüne göre baştan yazımı + 4 ajanlı doğruluk denetimi, DEVLOG eklemeleri.
- **v1.2** — **etkileşimli onboarding**: pasif animasyon yerine oyuncu, sabit-elle-hazırlanmış minik bir tahtayı (`4 5 3 / 7 2 3`, hedef 12) GERÇEK sürükleyerek çözer; aktif satır halkayla işaretli + üstünde **kayan parmak** (BoardWidget'in kendi geometrisiyle), temizleme/kazanma anını hisseder, sonra gerçek tahtasına iner. Tamamen kelimesiz. **Yeni GameMode EKLENMEDİ** (tutorial mantığı kendi `GameState`'iyle bir widget'ta izole — `_onWin`/coin/yıldız/win-sheet/streak'e dokunmadan). Tahta "mermi geçirmez": tek hedef-toplamı yolları iki satır → kazara temizleme yok, iki sırayla da kazanılır, çıkmaz yok (`tutorial_puzzle_test.dart` ile kanıtlı). Tasarım için 3-ajanlı judge-panel workflow'u; eski `onboarding_overlay.dart` silindi.
- **v1.3** — **viral spoiler-free Daily paylaşımı** (dağıtım motoru): Wordle tarzı **gün-numarası** (`REACH #160`), marka-renkli **grup imzası** (🟧 — yalnızca sayı, herkeste aynı), **yıldızlar** (⭐ /3 — artık paylaşımda), clean/ipucu rozeti, streak (🔥), ve **CTA linki** (`kShareUrl`, placeholder → yayında gerçek mağaza/smart-link). Spoiler-free *yapısal garanti*: builder yalnızca soyut metrik alır, hedef/değer/pozisyon hiç girmez. 8 test (`share_text_test.dart`).
- **v1.4** — paylaşımı **düz metin/.txt yerine görsel SONUÇ KARTI**'na çevirdik (kullanıcı geri bildirimi: ".txt indi, içerik kötü, ss alınabilir bir sonuç ekranı olmalı"). Yeni `ResultCard` (sakin, marka-içi: REACH başlığı, `DAILY #160`, 3 yıldız, clean/ipucu rozeti, grup imzası, streak, `reach.game` CTA — hepsi spoiler-free). `ShareResultScreen` kartı RepaintBoundary ile **PNG'ye render edip native paylaşıma resim olarak** verir (caption = emoji metni + URL fallback). Daily kazanım → paylaş artık bu ekranı açıyor. Görsel, gerçek fontlarla golden-render ile doğrulandı; 5 widget testi. Not: oyun adı (REACH) ve `kShareUrl` (reach.game) hâlâ tartışmalı/placeholder — kart `kAppName`'den okuduğu için isim değişimi bedava.
- **v1.5** — **analytics funnel enstrümantasyonu** + CTA boşa çekildi. Yeni event'ler: `onboarding_completed/skipped`, **`share_opened`/`share_completed`** (viral funnel — dağıtım için kritik), `shop_opened`. (Mevcut: board/daily/hint/ad + purchase/restore/coins zaten vardı.) `kShareUrl` şimdilik **BOŞ** — landing/store linki gelene dek sahte `reach.game` gösterilmiyor; hem paylaşım metni hem kart URL'i zarifçe atlıyor. README'ye **Analytics** bölümü + Firebase'i "config-drop" ile açma kılavuzu eklendi. **İsim kararı: REACH kalıyor** (adaylar beğenilmedi; jenerik kelime → domain/handle dolu/pahalı [reach.game ~$310/yıl premium], ama mağaza adı için domain şart değil; landing page sonraya). **Android testi ertelendi** — araç-zinciri (Android Studio/SDK) kurulu değil.
- **Bundle id sabitlendi:** `com.reach.reach` → **`com.utkuyuksel.reach`** (kalıcı; org segmenti = geliştirici handle'ı, oyun adından bağımsız). Tüm aynalar (iOS pbxproj, Android gradle namespace/applicationId, Kotlin paket dizini, IAP ürün id'leri) güncellendi.
- **v1.6 — Firebase Analytics bağlandı.** `firebase_core` + `firebase_analytics`; başlatma **`lib/firebase_options.dart`** ile (Dart-only → iOS plist'i Xcode target'ına ekleme / Android gradle eklentisi derdi YOK), yalnızca `kUseRealServices` dalında. `FirebaseAnalyticsService` (param sanitizasyonu: bool→0/1, null'ları atar). Çağrı yerleri değişmedi (funnel zaten enstrümante). **iOS deployment target 13→15** (Firebase SDK 12.14 şartı; ~%95+ aktif cihaz). Native config dosyaları `.gitignore`'da (firebase_options.dart ile redundant; client key'ler tek yerde). Firebase projesi: `reach-37923`. **Doğrulandı:** real-services build iOS simülatöründe pod install + derleme + launch sorunsuz, Firebase init çökme yok. ⏳ Kalan tek adım kullanıcıda: Firebase'de **Google Analytics'i aç** (config'te `IS_ANALYTICS_ENABLED=false`) → event'ler DebugView'e akar.

---

## 8. Sıradaki yol haritası

**Tamamlandı (son turlar):** find-and-clear pivotu, peg-solitaire çıkmaz, coin ekonomisi + analytics + remote-config, yıldız/clean, decoy-zorluk, **shop** (coin paketleri/Premium/coin'le temalar), **ses (SFX + ambient)**, shop cilaları (tema önizleme [uzun bas], yetersiz-bakiye kırmızı flash, seçim haptik'i), **etkileşimli onboarding** (rehberli ilk board, gerçek sürükleme + kayan parmak), **viral spoiler-free Daily paylaşımı** (gün-numarası + yıldız + grup imzası + CTA link).

**Yapılacaklar (Gemini'den süzülenler dahil):**
1. ~~Firebase'i bağla~~ ✅ **Bağlandı (v1.6)** — kod + init hazır, iOS sim'de doğrulandı. Kalan: kullanıcı Google Analytics'i açacak (DebugView için). Remote-config backend opsiyonel.
2. ~~Landing page~~ ✅ **Kodlandı** (`landing/`): statik, tek-dosya, SEO-odaklı (title/description/OG/Twitter/JSON-LD + robots + sitemap), marka-içi (paper/terracotta, Fraunces). `privacy.html` taslağı (ads/IAP/analytics gerçeğine göre — yayın öncesi gözden geçir). Kalan: domain al + `reachpuzzle.com` placeholder'ını değiştir + 1200×630 og-image + deploy (Netlify/Pages/Vercel) → sonra `kShareUrl` + `kPrivacyPolicyUrl`'ü bağla. Deploy adımları `landing/README.md`'de.
3. **Launch checklist (yayın öncesi, kod değil):** Gizlilik Politikası barındırma + **ToS/EULA** (coin/IAP gerektirir) + store-sayfası **ASO & yerelleştirme** (oyun-içi dil-bağımsız ama mağaza sayfası ayrı).
4. **Android testi (BLOKE)** — Android Studio/SDK kurulu değil; kurulunca emülatör/cihaz testi (haptics, safe-area, ad/IAP SDK).
5. (Sonra) **küçük test kampanyası** → D1/D7 + LTV/CPI ölç → tutuyorsa ölçekle.

**Park edilenler / bilinçli REDDEDİLENLER:**
- Yeni taş mekanikleri (buz / çarpan x2 / **eksi sayılar**) — komplekslik + bazıları çözülebilirlik modelini kırar + sakin markaya fazla. *Çekirdek doğrulanınca dikkatle düşünülebilir.*
- **Erken çıkmaz-uyarısı** — bilinçle reddedildi (ipucu değerini öldürür, brute-force'a açar). Peg-solitaire modeli tercih edildi.
- Sert fail / can sistemi / "baştan başla" — kitleye ters, churn riski.
- Yüksek-enerji "juice" (ekran titremesi/konfeti) — sakin tona ters; nazik dokunuşlar (pop, win-pulse) tercih edilir.

---

## 9. Çalıştırma & test (özet)

```bash
flutter pub get
flutter run                                  # dev: no-op ad/IAP stub'larıyla, hesap gerekmez
flutter test                                 # 69 test
dart analyze lib test                        # temiz (flutter analyze bu ortamda çöküyor)
flutter run --dart-define=REACH_AUTOSTART=zen   # dev: doğrudan bir Zen board'una açılır
flutter run --dart-define=REACH_REAL_SERVICES=true   # gerçek google_mobile_ads / in_app_purchase
```

Ayrıntı (gerçek ad/IAP id'leri, store kurulumu, rebrand) için bkz. `README.md`.

---

## 10. Açık kararlar / hatırlatmalar

- Coin/yıldız/decoy dengeleri analytics verisiyle ayarlanacak (hepsi remote-config'e hazır).
- Premium açıkken coin çipi gizli (tasarım); tam coin-shop'u görmek için Premium'suz test (uygulamayı silip yeniden kur).
- İsim/bundle id placeholder; rebrand tek dosyadan (`app_constants.dart`) + README'deki native mirror'lar.
