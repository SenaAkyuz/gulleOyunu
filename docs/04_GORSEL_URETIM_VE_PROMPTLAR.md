# 04 — Görsel Üretim Rehberi ve Prompt Kütüphanesi

> `docs/referans/` içindeki 6 görsel **temsilidir**: stil, renk ve his referansıdır; doğrudan oyuna konmaz.
> Bu doküman neyin **AI görseli**, neyin **3D model**, neyin **shader/efekt** olacağını ve hazır promptları içerir.
> Yeni prompt gerektiğinde: `/ordino-art-prompts` skill'i bu dosyadaki stil kılavuzunu kullanarak üretir.

---

## 1. Neyi nasıl üretiyoruz? (en önemli karar tablosu)

| Varlık | Yöntem | Neden | Ne zaman |
|---|---|---|---|
| Dünya arka planları (8) | **AI görsel** (GPT image vb.) | Resimsel, sinematik sahne; 3D'de yapmak çok pahalı | Faz 7 (MVP'de düz renk gradyan) |
| Arka plan hareketli öğeler (şelale, lav akışı, balık, bulut) | AI görsel (ayrı, şeffaf PNG) + shader/animasyon | Canlılık | Faz 7–8 |
| Dünya kartları (level map, 8) | **AI görsel** | Pazarlama kalitesinde kart | Faz 7 |
| **Bloklar** (taş, ahşap, kristal…) | **3D mesh (Blender scripti)** + **AI dikişsiz doku** | Fizikte dönen/kırılan nesne 2D resim olamaz | Faz 1'de primitif, Faz 7'de final |
| Kırık parçalar | Blender Cell Fracture (scriptle) | Gerçekçi kırılma | Faz 7 |
| Kaide / platform (dünya başına) | 3D mesh + AI doku | Blokların kenardan düşüşü 3D görünmeli | Faz 7 |
| Top (cannon) | 3D mesh (Blender) + AI doku, ya da 2D katmanlı sprite | Referanstaki kırmızı-altın top; sadece döner | Faz 7 |
| Gülleler – oyun içi | 3D küre + **shader** (alev, elektrik, girdap) + parçacık | Hareketli efekt resimle olmaz | Faz 5/8 |
| Gülleler – UI ikonları (6) | **AI görsel** (şeffaf PNG) | Mağaza ve seçici ikonları | Faz 6–7 |
| Altın Küre | 3D küre + altın PBR + glow | | Faz 1 |
| UI kiti (buton, panel, yıldız, altın, rozet) | **AI görsel** + 9-slice düzenleme | Tutarlı premium UI | Faz 7 |
| VFX dokuları (kıvılcım, duman, cam kıymığı, ateş) | AI görsel (siyah zeminde) veya hazır ücretsiz paketler | | Faz 8 |
| Uygulama ikonu, mağaza görselleri, tanıtım videosu | AI görsel + oyun içi ekran görüntüsü; video için (ör. Higgsfield gibi video araçları) | | Faz 11 |

**Cevap: "Her taş için GPT promptu gerekir mi?"** → **Hayır.** Bloklar 3D model olacak; her **malzeme** için 1 dikişsiz doku promptu yeter
(taş, ahşap, kristal, buz, lav taşı, metal…  ~12 doku). Arka planlar, kartlar, ikonlar ve UI için prompt gerekir (~60 görsel toplam).

---

## 2. Stil kılavuzu (Style Bible) — her promptun başına eklenir

```
[ORDINO STYLE BIBLE]
Premium stylized 3D mobile game art, semi-realistic hand-painted look, rendered like a high-end casual puzzle game.
Vibrant saturated colors, warm golden accents, soft global illumination, gentle bloom on light sources,
crisp readable silhouettes, glossy highlights on stone and crystal, painterly sky and clouds,
rich depth with atmospheric perspective. Friendly, magical, inviting mood. No characters, no text, no logos, no UI.
Clean composition with a clear empty central stage.
```

**Renk kuralları:**
- Oyunun "imza" renkleri: **altın sarısı** (küre, top süslemeleri, UI çerçeveleri), **turkuaz** ve **amber** kristaller, **kırmızı** top.
- Arka plan **oyun alanından daha düşük kontrastlı** olmalı: kule ve bloklar her zaman öne çıkar. Arka planı %10–15 bulanık/yumuşak tutun.
- Her dünya bir **baskın renk ailesi**: Akdeniz=turkuaz/krem, Korsan=sıcak turuncu/kahve, Yanardağ=kırmızı/turuncu/siyah, Buz=mavi/beyaz,
  Çöl=altın/kum, Orman=mor/yeşil, Gökyüzü=pastel mavi/pembe, Sualtı=derin mavi/turkuaz.

## 3. Arka plan kompozisyon kuralları (çok önemli)

```
 ┌──────────────────────┐  1080 x 1920 (portre). Üretim: 1024x1536 → 2x upscale.
 │  ÜST %12: sakin gök   │  ← HUD buraya gelir (level, gülle, ayar). Detay az.
 │                      │
 │   ARKA SAHNE         │  ← dünyanın kimliği: uzak yapılar, dağlar, gemi direği…
 │   (yanlarda yoğun)    │
 │ ┌────────────────┐   │
 │ │  BOŞ MERKEZ    │   │  ← %25–70 dikey: KULE ALANI. Burada hiçbir nesne olmamalı,
 │ │  (kule alanı)  │   │     sadece yumuşak arka plan. Kaide 3D olarak Godot'ta eklenir.
 │ └────────────────┘   │
 │  ZEMİN / ÖN DEKOR     │  ← %72–100: zemin, köşelerde dekor (vazo, fıçı, mercan…)
 │  (orta alt boş: top)  │     alt ortada top (cannon) için boşluk.
 └──────────────────────┘
```
Her arka plan promptuna eklenecek kompozisyon bloğu:
```
[COMPOSITION]
Vertical portrait 2:3 composition. Keep the central area (from 25% to 70% of the height, middle 70% of the width) completely empty and calm —
no objects, no structures, no towers in the center; this is where gameplay happens.
Decorative elements only along the left and right edges and in the bottom corners. Keep the bottom-center area clear for a cannon.
Keep the top 12% simple sky/ceiling for UI. Slightly soft focus on the background for depth. Eye-level camera, slight low angle.
```
**Negatif kısıtlar (her zaman ekle):** `Do not include: towers, blocks, cannon, balls, characters, people, text, letters, numbers, logos, UI, frames, watermarks.`

**Referans görsel kullanımı:** GPT görsel üretiminde ilgili referans görselini (örn. `02_gameplay_col_yanardag.png`) ekleyip şunu yaz:
`Use the attached image ONLY as a style and color reference for the environment. Do not copy the tower, the cannon or the UI.`

### 3.1 Katmanlama (paralaks için)
1. **Tam sahne** (yukarıdaki prompt) → `far.webp` olarak kullanılabilir.
2. Ön dekor (sol/sağ köşe öğeleri) ayrı: `transparent background PNG, isolated foreground props for the left/right corners` → `front.png` (hafif paralaks + titreşimle kımıldar).
3. Animasyonlu öğe (şelale akışı, lav, balık sürüsü) ayrı şeffaf PNG veya Godot shader'ı ile.

---

## 4. Dünya arka plan promptları (8) — kopyala-yapıştır

> Her birinin önüne **[ORDINO STYLE BIBLE]**, sonuna **[COMPOSITION]** + negatif kısıtları ekle.

**1. Akdeniz Sahili (`akdeniz`)**
```
A sunny Mediterranean coastal cove at golden afternoon. Turquoise crystal-clear shallow water, white limestone cliffs,
ancient Greek-style stone arches and columns on the left and right edges, magenta bougainvillea flowers draping over ruins,
distant small white island with an old temple, soft fluffy clouds, sparkling sea reflections. Foreground: sunlit pale stone tiles,
terracotta amphora vases and flowers in the bottom corners.
```
**2. Korsan Gemisi (`korsan`)**
```
The open main deck of a grand wooden pirate ship at sunset. Warm orange and pink sky over the ocean, tropical cliffs with a waterfall in the distance,
ship's wheel on the left edge, rigging ropes and a tattered black flag with a skull on the right edge, glowing brass lanterns,
polished wooden deck planks in the foreground, barrels, coiled rope, treasure chest with gold coins, spyglass and compass in the bottom corners.
```
**3. Yanardağ (`yanardag`)**
```
A dramatic volcanic landscape at dusk. An erupting volcano in the far background with glowing lava rivers running down,
dark basalt rock formations with glowing orange cracks on both edges, rising embers and ash particles in the air, smoky red-purple sky,
glowing orange-red crystals growing from rocks in the bottom corners, cracked obsidian ground with thin lava veins in the foreground.
```
**4. Buz Mağarası (`buz`)**
```
A magical ice cave interior. Huge translucent blue icicles hanging from the ceiling, glowing cyan crystal clusters on the left and right walls,
a bright icy tunnel opening glowing in the far background, frozen lake floor with mirror reflections in the foreground,
snow-covered rocks and ice crystals in the bottom corners, floating sparkles, cool blue and white palette with soft cyan glow.
```
**5. Çöl Vadisi (`col`)**
```
A golden desert valley under a bright blue sky. Rolling sand dunes, an ancient sandstone fortress and arched aqueduct ruins on the edges,
a caravan of camels small in the far distance, palm trees on the left edge, a colorful market tent awning on the right,
warm sand ground with ornate clay pots and desert plants in the bottom corners, heat haze, warm golden light.
```
**6. Büyülü Orman (`orman`)**
```
An enchanted mystical forest at twilight. Giant ancient trees with twisting roots, glowing purple and teal mushrooms,
floating fireflies and magical particles, soft beams of light through the canopy, hanging vines on both edges,
mossy stones and glowing violet crystals in the bottom corners, a calm reflective stream in the foreground, purple-green palette.
```
**7. Gökyüzü Adaları (`gokyuzu`)**
```
Floating sky islands high above the clouds at dawn. Small grassy floating islands with waterfalls pouring into the clouds,
ancient stone arches and a distant white fairytale castle on a floating island, rope bridges between islands at the edges,
pastel pink and blue sky, sea of soft clouds below, pink flowers and grassy rock ledge in the bottom corners.
```
**8. Sualtı Harabeleri (`sualti`)**
```
Sunken ancient ruins deep underwater. Shafts of sunlight streaming down from the surface, broken marble columns and a giant stone statue head on the edges,
colorful pink and purple coral reefs, swaying seaweed, schools of small tropical fish and a sea turtle in the distance, rising bubbles,
sandy sea floor with starfish, an anchor and an open treasure chest with gold coins in the bottom corners, deep blue and turquoise palette.
```

## 5. Dünya kartları (level map) — 8 adet
Kart, o dünyanın **ikonik bir kulesini** gösterir (kartta kule olabilir, oyunda olmaz).
```
[ORDINO STYLE BIBLE]
Square 1:1 hero illustration card for the world "<DÜNYA ADI EN>". In the center, an iconic stacked tower made of
<dünyanın malzemeleri: e.g. limestone arches, wooden planks and glowing amber and turquoise glass cubes>, with a shiny golden sphere hanging inside a stone arch.
Background: <dünya arka plan özeti, 1 cümle>. Strong rim light, cinematic, very readable at small size. No text, no frame, no UI.
```
Kart çerçevesi, isim şeridi ve yıldız rozeti **UI'da** (Godot) eklenir → görselde yazı **olmamalı** (Türkçe karakterleri AI bozar).

## 6. Top ikonları (6) — şeffaf arka plan
```
[ORDINO STYLE BIBLE]
Game item icon, a single <TOP TANIMI> centered, 3/4 view, isolated on a fully transparent background, soft drop glow,
strong readable silhouette, 1024x1024. No pedestal, no text.
```
| Top | `<TOP TANIMI>` |
|---|---|
| Ağır | `heavy dark iron cannonball with hammered metal texture and subtle scratches, cool steel highlights` |
| Alev | `molten fireball with cracked glowing lava crust, bright orange-yellow flames wrapping around it` |
| Kesici Çark | `spinning circular steel saw blade with sharp teeth and a golden center hub, motion sparks` |
| Buz | `faceted ice crystal sphere, translucent pale blue, frost mist and tiny snowflakes around it` |
| Elektrik | `dark blue energy orb with crackling violet lightning arcs over its surface` |
| Çekim | `swirling purple vortex sphere like a tiny black hole, small rock fragments orbiting it` |

(Referans: `06_ozel_top_seti.png` — kaideler olmadan, sadece top.)

## 7. Malzeme dokuları (dikişsiz) — 3D bloklar için
```
Seamless tileable PBR texture, flat orthographic top-down view, even diffuse lighting, no shadows, no perspective, no objects,
stylized hand-painted game texture matching a vibrant premium mobile game, 1024x1024, <MALZEME TANIMI>.
```
| Malzeme | `<MALZEME TANIMI>` |
|---|---|
| stone | `warm cream limestone blocks, soft worn edges, subtle cracks, light beige` |
| wood | `rich brown wooden planks with visible grain, slightly painted, iron bolt holes` |
| crate | `light wooden crate boards with an X brace pattern` (yüz dokusu, dikişsiz değil) |
| crystal_amber | `glowing amber glass with inner light and subtle internal facets` |
| crystal_cyan | `glowing turquoise glass with inner light and subtle internal facets` |
| ice | `translucent blue ice with frost and trapped bubbles` |
| lava_rock | `dark basalt rock with glowing orange lava cracks` (+ ayrı emissive maske iste) |
| metal | `riveted dark steel plates with brass rivets` |
| snow_stone | `grey stone covered with soft snow on top edges` |
| sandstone | `golden sandstone with carved ornamental patterns` |
| mossy_stone | `grey stone with green moss and tiny glowing spores` |
| coral_stone | `pale marble stone with barnacles and small coral growth` |

Normal/roughness haritaları: albedo'dan türet (ör. Materialize / Godot içi araç / Blender scripti) — Claude script yazabilir.

## 8. UI kiti promptu
```
[ORDINO STYLE BIBLE]
Mobile game UI kit sprite sheet on a transparent background: rounded dark navy glossy panels with thin golden borders,
large golden buttons with soft bevel (normal and pressed states), circular gear settings button, back arrow button,
three golden stars (filled and empty), gold coin icon, purple gem icon, plus button, lock icon, shot indicator pearls (white glowing and empty),
laurel decorations. Evenly spaced, each element separated. No text.
```
Sonra Claude/Sena elemanları kesip `assets/ui/` altına 9-slice ayarlarıyla koyar. Yazılar Godot'ta font ile (ör. kalın, yuvarlak, Türkçe karakter destekli bir font).

## 9. Kalite kontrol listesi (her görsel için)
- [ ] Merkez kule alanı boş mu? Kule/yazı/karakter yok mu?
- [ ] Arka plan, oyun bloklarından daha az kontrastlı mı? (Üstüne gri kutu koyup test et.)
- [ ] Dünyanın renk ailesine uyuyor mu? Diğer 7 dünya ile yan yana tutarlı mı?
- [ ] Alt orta (top) ve üst şerit (HUD) sakin mi?
- [ ] Çözünürlük ≥ 1024×1536; upscale sonrası artefakt yok mu?
- [ ] Dosya adı kuralı: `assets/backgrounds/<world_id>/far.webp`

## 10. Prompt üretme kararı — ne zaman?
- **Şimdi (Faz 0–1):** Stil kılavuzu sabit. Görsel üretme; gri kutu prototiple oyunun eğlenceli olduğunu kanıtla.
- **Faz 7'de:** Claude, `/ordino-art-prompts` ile her dünyaya özel tam prompt setini (arka plan + ön dekor + kart + platform dokusu) üretir;
  Sena görselleri üretip `incoming_art/` klasörüne atar; Claude isimlendirip doğru yerlere yerleştirir ve kalite kontrol listesini uygular.
