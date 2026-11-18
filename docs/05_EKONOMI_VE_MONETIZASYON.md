# 05 — Ekonomi ve Monetizasyon

> Tüm sayılar `game_data/economy.json` ve `game_data/balls.json` içindedir. Buradaki tablolar **başlangıç önerisidir**.
> Değiştirdikten sonra `python3 tools/economy_sim.py` çalıştır → oyuncunun hangi bölümde ne kadar altını olduğunu görürsün.

## 1. Para birimleri
| Birim | Kazanım | Harcama | v1? |
|---|---|---|---|
| **Altın** 🪙 | Bölüm yıldızları, kristal kırma, dünya bitirme, ödüllü reklam, IAP | Özel top paketleri, +1 gülle | ✅ |
| Elmas 💎 | IAP, nadir ödüller | Premium içerik, kostümler (top görünümleri) | ⏸ (sistem hazır, kapalı: `economy.currencies.gem.enabled=false`) |

## 2. Altın kazanımı ⚙️ `economy.json → rewards`
| Kaynak | Değer (öneri) | Not |
|---|---|---|
| ⭐ 1 yıldız (ilk geçiş) | 10 | |
| ⭐⭐ 2 yıldız (ilk geçiş) | 20 | |
| ⭐⭐⭐ 3 yıldız (ilk geçiş) | 35 | Fark büyük → 3 yıldız için tekrar oynama motivasyonu |
| Tekrar oynama (yıldız artırmadan) | ilk değerin %20'si | Altın "farm"ını sınırlar |
| Yıldız yükseltme (1→3) | `fark` (35−10=25) + tekrar ödülü | Asla eksik/fazla ödeme yok |
| Kristal blok kırma | +1 / kristal (bölüm başı tavan 8) | Yıkımı ödüllendirir |
| **Altın Küre jackpot** (K-018) | 20 (taslak, `rewards.core_jackpot_gold`) | `clear_percent` bölümünde kazanırken küre de düştüyse. Bölümdeki **ilk** jackpot tam, sonrakiler `× replay_ratio` (farm önleme). Yıldızı etkilemez |
| Boss bölüm | yıldız ödülü × 2 | |
| Dünyayı bitirme | 100 | |
| Dünyada 30/30 yıldız | 150 + (ileride) özel top görünümü | |
| Ödüllü reklam: "ödülü 2x yap" | ×2 | Günlük limit ⚙️ |

**Formül (kod):**
```
first_clear_reward = rewards.stars[stars]
replay_reward      = round(rewards.stars[stars] * rewards.replay_ratio)
upgrade_reward     = rewards.stars[new] - rewards.stars[old]
jackpot            = core_dropped ? (ilk jackpot ? rewards.core_jackpot_gold : round(rewards.core_jackpot_gold * rewards.replay_ratio)) : 0
total = (ilk geçiş ? first_clear_reward : upgrade_reward + replay_reward) * (boss ? boss_mult : 1) + crystal_coins + jackpot
```

## 3. Altın harcama ⚙️
| Ürün | Fiyat (öneri) |
|---|---|
| Alev Topu ×3 | 120 |
| Kesici Çark ×3 | 150 |
| Buz Topu ×3 | 180 |
| Elektrik Topu ×3 | 220 |
| Çekim Topu ×2 | 300 |
| +1 Gülle (başarısız ekranında) | 50 (veya ödüllü reklam) |

**Denge hedefi (sim ile kontrol):** Ortalama oyuncu (ortalama 2.2 yıldız) her dünya sonunda **2–3 özel top paketi** alabilecek kadar altın biriktirmeli.
Çok cömert → IAP satmaz; çok cimri → oyuncu sıkılır. Hedef: oyuncuların ~%3–5'i IAP yapsın, kalanlar özgürce oynayabilsin.

## 4. Gerçek parayla altın (IAP) ⚙️ `economy.json → iap_products`
| Ürün id | İçerik | Fiyat kademesi (öneri) |
|---|---|---|
| `gold_s` | 500 altın | ~$0.99 |
| `gold_m` | 1.300 altın (+%30) | ~$1.99 |
| `gold_l` | 3.500 altın (+%40) | ~$4.99 |
| `gold_xl` | 8.000 altın (+%60) "En popüler" | ~$9.99 |
| `gold_xxl` | 18.000 altın (+%80) "En iyi değer" | ~$19.99 |
| `starter_pack` | 1.000 altın + her özel toptan 2 adet (tek seferlik, 3. dünyada gösterilir) | ~$2.99 |
| `remove_ads` | Zorunlu reklam yok (v1'de zaten yok → ileride) | ~$3.99 |

- Gerçek fiyatlar App Store Connect / Google Play Console'da **fiyat kademesi** olarak ayarlanır; JSON'daki fiyat yalnızca yedek gösterimdir, ekranda **mağazadan gelen yerelleştirilmiş fiyat** gösterilir (₺ dahil).
- Altın = **tüketilebilir (consumable)** ürün. Satın alma doğrulaması: v1'de istemci taraflı; ileride sunucu doğrulaması.

## 5. Reklam (opsiyonel, v1 sınırlı)
- Yalnızca **ödüllü reklam**: "+1 gülle", "ödülü 2x", "günlük bedava top". Zorla gösterilen (interstitial) reklam **yok** (v1).
- `AdsService` arayüzü; sağlayıcı (AdMob vb.) Faz 10'da güncel Godot eklentisine göre seçilir.

## 6. Etik ve mağaza kuralları
- Gerçek para ile satın alma ekranında içerik net yazılır; "loot box" (rastgele ödül) **yok**.
- Çocuk oyuncu ihtimali yüksek → ebeveyn kapısı (yaş kapısı) ve mağaza politikalarına uyum (Faz 11 kontrol listesi).
- Satın alma işlemleri iade/geri yükleme (restore) desteklemeli (iOS zorunlu, tüketilebilirde "remove_ads" için).

## 7. Analitik olaylar (denge için şart)
`level_start`, `level_complete(stars, shots_used, ball_used)`, `level_fail(attempt)`, `ball_purchase(id, price)`, `gold_earn(reason, amount)`,
`gold_spend(reason, amount)`, `iap_purchase(product)`, `shop_open(source)`, `ad_reward(placement)`.
Bunlarla: hangi bölümde oyuncu takılıyor (fail oranı), ekonomi enflasyonu, hangi top popüler → JSON'u güncelle.
