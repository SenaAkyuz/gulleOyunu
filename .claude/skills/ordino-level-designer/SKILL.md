---
name: ordino-level-designer
description: Ordino Games için yeni bölüm/kule tasarlar veya mevcut bölümü değiştirir (zorluk, malzeme, şablon, çift kule, boss). Bölüm JSON'u yazar, doğrular ve tasarım gerekçesini Türkçe açıklar. "bölüm yap", "kule tasarla", "level", "zorlaştır/kolaylaştır" isteklerinde kullan.
---

# Ordino Bölüm Tasarımcısı

## Önce oku
1. `docs/03_KULE_VE_BOLUM_TASARIMI.md` (şablonlar, keystone kuralı, ritim, sim hedefleri)
2. `game_data/difficulty.json` (bölümün zorluk puanı ve rolü buradan hesaplanır)
3. `game_data/worlds.json` (dünyanın paleti, izinli şablonlar, modifier'lar, joint türleri)
4. `game_data/shapes.json`, `game_data/materials.json`
5. Aynı dünyanın mevcut bölümleri → **aynı şablonu art arda iki bölümde kullanma**.

## Adımlar
1. **Hesapla:** `difficulty = (world_base.start + (world_index-1)*step) + rhythm[level].offset`, sonra `× global_multiplier`, 1–100'e kırp. Rolü al.
2. **Parametreleri türet:** `curves` üzerinden doğrusal interpolasyonla block_count, height, heavy_ratio, shots, aim_preview_dots, symmetry, structure_count, depth_layers.
3. **Kurgu cümlesi yaz (1 cümle):** "Oyuncu şunu keşfedecek: …" (ör. "soldaki ince kuleyi sağdakinin üstüne devirmek"). Kurgu yoksa bölüm yapma.
4. **Yerleşim (tam 3D, K-002):** Şablon(lar)ı seç, blokları grid biriminde yerleştir: `x, z` = taban merkezi, `y` = alt yüzey,
   `rot: [rx, ry, rz]` derece. Eksenler: x sağ, y yukarı, z ön (kameraya doğru). Oynanabilir alan x −5…+5, z −3…+3, y 0…12.
   Platform `width` (x) × `depth` (z); bloklar kenardan en az 0.3 birim içeride.
   - **3D statik denge:** her bloğun ve üstündeki yükün birleşik ağırlık merkezi (x, z), alttaki destek poligonunun içinde (`rules.physics.support_margin`).
   - Ağır malzeme alta/sütunlara, kristaller görünür ve kırılabilir yerlere.
   - 1–3 **keystone** işaretle. **Kamera kuralı (S-007):** v1'de kamera sabit (`rules.camera`: çapraz, ~20° yukarıdan) →
     **her keystone varsayılan kamera açısından görünür olmalı** (en az bir yüzü açıkça görünür, başka bloğun arkasında değil)
     ve toptan (≈ 0, −1, +8) doğrudan ya da lob atışla ulaşılabilir olmalı.
   - Top tanıtım bölümüyse (`balls.json → tutorial_level_id`) kuleyi o topun güçlü olduğu malzemelerle kur, `free_balls` ver.
5. **JSON yaz:** `game_data/levels/<wNN_dunya>/<id>.json`, format `docs/03 §2.1`. Elle tasarımda `baked: true`.
6. **Doğrula:** `python3 tools/validate_game_data.py` → hata yoksa devam.
7. **Sim varsa çalıştır** (Faz 3 sonrası `src/tools/sim`), metrikleri `sim_targets` ile karşılaştır, gerekirse düzelt.
8. **Sena'ya rapor (Türkçe):** ASCII çizim (önden **ve** üstten görünüm) + kurgu + keystone'lar + zorluk + "3 yıldız nasıl alınır" + nasıl test edilir.

## ASCII çizim örneği (rapor için)
```
y4        [◎]          ◎ = Altın Küre
y3   [▓][==K==][▓]     ▓ taş, K keystone (ahşap kiriş), ◆ kristal
y2   [▓] (  ) [▓]
y1   [▓][◆][◆][▓]
y0 ═══════════════════ platform
```
Üstten görünüm (x →, z ↓ = kameraya doğru):
```
z-1  [▓]   [▓]   [▓]
z0   [▓]  [◆K]   [▓]     K ön sırada → kameradan görünür ✅
z+1  ───── ön kenar ─────
```

## Yasaklar
- Sim/test olmadan "çözülebilir" deme.
- Keystone'suz bölüm yapma.
- Varsayılan kameradan görünmeyen (arkada saklı) keystone kullanma.
- Kristalsiz kule yapma (her kulede kırılacak parlak bir şey olmalı).
- `difficulty.json`'u bölüm için değiştirme; bölüme özel ayar `modifiers_override` ile yapılır.
