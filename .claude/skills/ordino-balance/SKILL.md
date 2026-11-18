---
name: ordino-balance
description: Ordino Games ekonomi ve zorluk dengesini analiz eder ve ayarlar - yıldız ödülleri, top fiyatları, açılma noktaları, hediye adetleri, IAP paketleri, zorluk eğrisi, global zorluk çarpanı. "altın çok/az", "top pahalı", "oyun zor/kolay", "denge", "fiyat" isteklerinde kullan.
---

# Ordino Denge Uzmanı

## Önce oku
`docs/05_EKONOMI_VE_MONETIZASYON.md`, `docs/03 §6`, `game_data/economy.json`, `game_data/balls.json`, `game_data/difficulty.json`, `game_data/worlds.json`.

## Adımlar
1. **Mevcut durumu ölç:** `python3 tools/economy_sim.py` çalıştır, tabloyu Sena'ya göster. Varsa analitik verisini (fail oranı, satın almalar) iste.
2. **Sorunu tanımla:** Hangi metrik hedef dışı? (paket/dünya, belirli bölümde takılma, top hiç alınmıyor…)
3. **En küçük değişikliği öner:** Tek seferde 1–2 parametre. Her öneri için: *ne değişir, neden, oyuncuya etkisi, risk*.
   - Tüm oyun zor/kolay → önce `difficulty.global_multiplier` (±0.05–0.1).
   - Tek bölüm zor → o bölümün `shots` veya yapısı (level-designer'a devret).
   - Altın enflasyonu → `rewards.stars` veya `replay_ratio`; top fiyatına dokunmadan önce ödüle bak.
   - Top hiç kullanılmıyor → hediye adedi, tanıtım bölümü, fiyat — bu sırayla.
4. **Sena onaylarsa** JSON'u düzenle → `python3 tools/validate_game_data.py` → `python3 tools/economy_sim.py` → önce/sonra tablosu.
5. `docs/08_KARAR_GUNLUGU.md`'ye kısa kayıt ekle (değer, gerekçe, tarih).

## İlkeler
- Ücretsiz oyuncu oyunu bitirebilmeli; IAP hızlandırır, zorunlu kılmaz.
- 3 yıldız ödülü 1 yıldızın ≥ 3 katı olmalı (tekrar oynama motivasyonu).
- Yeni top açılınca oyuncu en az 1 kez "vay" demeli → hediye ≥ 2.
- Kod içine sayı gömme; her şey JSON.
