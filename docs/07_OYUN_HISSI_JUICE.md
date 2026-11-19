# 07 — Oyun Hissi (Juice): "Physics. Impact. Satisfaction."

> Bu oyunun ürünü **tatmin hissidir**. Aynı fizik, juice olmadan sıkıcı; juice ile bağımlılık yapar.
> Tüm şiddet değerleri `game_data/rules.json → feel` altında ayarlanabilir. Ayarlar ekranında "Titreşim" ve "Ekran sarsıntısı" kapatılabilir.

## 1. Atış anı
| Öğe | Detay |
|---|---|
| Nişan | Top namlusu parmağı yumuşak takip eder (lerp), yörünge noktaları hafif nabız atar |
| Ateşleme | Namlu geri teper (recoil, 0.12 sn), ağızdan duman + kıvılcım, kısa kamera itme (punch) geriye, `Haptics.light` |
| Ses | Derin "BOOM" + metalik çınlama, pitch ±%5 rastgele |
| Gülle göstergesi | Kullanılan inci (●) söner ve küçülür |

## 2. Çarpma anı (IMPACT)
| Öğe | Detay |
|---|---|
| **Hit-stop** | Büyük darbede (impulse > `feel.hitstop_threshold`) zaman 40–70 ms neredeyse durur (`Engine.time_scale = 0.05`) |
| Kamera sarsıntısı | "Trauma" modeli: `shake = trauma²`, trauma darbe büyüklüğüyle artar, zamanla söner; maks. ofset 0.25 birim, maks. rotasyon 1.5° |
| Parçacık | Malzemeye göre: taş → toz + taş kırıntısı; ahşap → kıymık; kristal → parlak cam kıymıkları + ışık patlaması; buz → kar tozu |
| Ses | Malzeme × şiddet katmanı: `impact_<material>_<light|heavy>`, aynı karede çok ses → sınırla (voice limit 8) |
| Titreşim | Hafif/orta/ağır (darbe şiddetine göre), kristal kırılmada kısa çift titreşim |
| Kırılma | Blok → parçalar + flaş, kristal kırılınca küçük altın 🪙 uçar (HUD'a) |

## 3. Çöküş anı (SATISFACTION)
- Zincirleme düşüş sayacı: "x5 ZİNCİR!" yazısı (blok-blok kırılmaları sayılır).
- **Doluluk çubuğu (K-018):** HUD'da (üst orta, gülle göstergesinin altında) temizlenen blok hacmi / hedef. Her düşen blokla yumuşakça dolar,
  %80 hedef çizgisi işaretli; hedefe yaklaşınca nabız atar, ulaşınca parlar + "TEMİZ!" + yükselen nota. Çubuk anlık
  (canlı) değeri gösterir; hedefe ulaşıldığı an bölüm kazanılır (sürekli atış).
- **Ağır çekim kapalı (Faz 1 oynanış geri bildirimi, 2026-11-19):** `rules.feel.slowmo_enabled = false` → jackpot'ta ve küre düşüşünde ağır çekim yok
  (sürekli atışla çakışıyor ve akışı kesiyordu). **Faz 8'de** yalnızca **kazanma anında kısa vurgu** olarak yeniden denenecek (`final_slowmo_*` değerleri saklı).
- **Altın Küre jackpot:** küre platformdan ayrıldığı an → (ağır çekim kapalı), kamera küreye
  hafif zoom → altın ışık patlaması + "ding" + **konfeti** + büyük "JACKPOT! +N 🪙" yazısı, altınlar HUD sayacına uçar. Yıldızı etkilemez.
- Otomatik final temizliği **yok**: hedef tutunca kalan bloklar platformda kalır (oyuncu kendi yıkımını görür).
- Platform dışına düşen her blok kısa "whoosh" + düşme sesi (uzakta, düşük ses).

## 4. Sonuç ekranı
- Yıldızlar tek tek, her biri büyüyüp "çarparak" yerleşir (scale 1.6 → 1.0, elastic easing), her yıldızda yükselen nota.
- Altın sayacı: rakamlar yuvarlanarak artar, altın ikonları ekrandan HUD'a yay çizerek uçar.
- 3 yıldızda ekstra parlama + "MÜKEMMEL!".
- Jackpot alındıysa ayrı satır: Altın Küre ikonu + "+N" (yıldız altınından sonra sayılır).

## 5. Özel top efektleri
| Top | Uçuşta | Çarpmada |
|---|---|---|
| Alev | Ateş izi (trail), ısı dalgası shader | Tutuşma: blok üzerinde alev parçacıkları, kararma (char) shader'ı, yayılma |
| Kesici Çark | Dönen bıçak, metal kıvılcım izi | Kesme çizgisi parlaması, blok iki parçaya ayrılır |
| Buz | Soğuk sis izi | Don dalgası halkası, bloklar mavi buz kaplaması (shader), "çıtırdama" sesi |
| Elektrik | Çatırdayan şimşek | Bloklar arası zincir şimşek (Line3D/mesh), mor flaş, kısa titreşim dizisi |
| Çekim | Girdap distorsiyon shader | Kara delik: çevre bükülmesi, parçalar spiral çekilir, sonra patlama dalgası |

## 6. UI hissi
- Tüm butonlar: basınca %92'ye küçül, bırakınca %105 → %100 (spring). Tıklama sesi.
- Kilitli dünya kartına dokununca sallanma + kilit sesi.
- Yeni top açılınca: tam ekran sinematik kart, ışın arka planı, top dönerek gelir.

## 7. Performans güvenliği
- Aynı anda maks. parçacık patlaması `feel.max_concurrent_bursts`. Fazlası birleştirilir.
- Kalite `low`'da: hit-stop ve sarsıntı kalır (ucuz), parçacıklar %50, debris fiziği yok.

## 8. Kontrol listesi (her yeni özellik için `/ordino-game-feel` uygular)
- [ ] Görsel geri bildirim var mı (parçacık/animasyon)?
- [ ] Ses var mı, pitch varyasyonu var mı?
- [ ] Titreşim uygun mu (ve ayardan kapatılabilir mi)?
- [ ] Zamanlama: tepki ≤ 1 kare gecikmeli mi?
- [ ] Abartılı mı? (Ekran sarsıntısı oyuncuyu yormamalı)
- [ ] Değerler `rules.json → feel` altında mı?
