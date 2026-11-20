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

### 3.0 Uzun telefonlar ve çentik (Sena, 2026-11-20, K-035) — §3'ün yerine geçen ölçüler
Üretim 2:3 (1024×1536 → 2× upscale). Oyunda arka plan **ekran yüksekliğini doldurur, yanlar kırpılır** (yatay ortalı): 9:16'da görselin ortadaki %84'ü,
iPhone 19.5:9'da ortadaki **%69**'u görünür. Bu yüzden:
- **Üst %18 sakin gökyüzü** (çentik / Dynamic Island + HUD; eski %12 yerine).
- **Oyun alanı:** genişliğin ortadaki %50'si (x %25–75), yükseklik %20–72 → boş ve sakin (kule + kaide burada; ölçüm: L01–L10 ekran görüntüleri).
- **Dünyanın kimliği** (kayalık, kemer, sütun, ağaç…) **kenardan %10–25 içeride** (x %10–25 ve %75–90) — uzun telefonda da görünür. En dıştaki %10 sade devam (kırpılabilir).
- **Alt:** %72–100 zemin; köşe dekoru x %10–35 / %65–90; alt orta (x %40–60) top için boş; en alt %5 sade (ana ekran çizgisi).

```
[COMPOSITION — TALL PHONES]
Vertical portrait 2:3 canvas. The game fills the screen height and crops the sides on tall phones, so only the middle 70% of the width is always visible.
Keep the top 18% a calm, simple sky with only soft clouds (phone notch and game UI sit there).
Keep the middle 50% of the width, from 20% to 72% of the height, completely empty and calm — no objects, no structures; gameplay happens there.
Place the scene's identity elements in the bands 10%–25% and 75%–90% of the width, not at the extreme edges; the outermost 10% on each side is simple continuation.
Ground from 72% of the height down; decorative props only in the bottom corners between 10%–35% and 65%–90% of the width; keep the bottom center clear for a cannon;
keep the bottom 5% simple. Slightly soft focus for depth. Eye-level camera, slight low angle.
```

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

## 11. Dünya 1 (Akdeniz) — Faz 7 dikey dilim prompt seti (2026-11-20)
Referans: `incoming_art/ref_akdeniz.png` (05 numaralı level map görselinin Akdeniz kartı). Görseller `incoming_art/` klasörüne, aşağıdaki adlarla.
Kompozisyon: §3.0 (uzun telefon / çentik, K-035).

| # | Dosya (incoming_art) | Hedef | Model ayarı | Referans |
|---|---|---|---|---|
| 1 | `akdeniz_far.png` | `assets/backgrounds/akdeniz/far.webp` | 1024×1536 portre, opak | ref_akdeniz.png |
| 2 | `akdeniz_front.png` | `assets/backgrounds/akdeniz/front.png` | 1024×1536 portre, **şeffaf** | ref_akdeniz.png |
| 3 | `akdeniz_card.png` | `assets/ui/cards/akdeniz.png` | 1024×1024, opak | ref_akdeniz.png |
| 4 | `tex_limestone_plinth.png` | `assets/textures/platform/limestone_plinth.png` | 1024×1024 dikişsiz | yok |
| 5 | `tex_stone.png` | `assets/textures/materials/stone.png` | 1024×1024 dikişsiz | yok |
| 6 | `tex_wood.png` | `assets/textures/materials/wood.png` | 1024×1024 dikişsiz | yok |
| 7 | `tex_crystal_amber.png` | `assets/textures/materials/crystal_amber.png` | 1024×1024 dikişsiz | yok |
| 8 | `tex_crystal_cyan.png` | `assets/textures/materials/crystal_cyan.png` | 1024×1024 dikişsiz | yok |

Tam promptlar: Sena'ya verilen mesajda ve aşağıda (kopyala-yapıştır).

**1. akdeniz_far**
```
[ORDINO STYLE BIBLE] Premium stylized 3D mobile game art, semi-realistic hand-painted look, rendered like a high-end casual puzzle game. Vibrant saturated colors, warm golden accents, soft global illumination, gentle bloom on light sources, crisp readable silhouettes, glossy highlights on stone and crystal, painterly sky and clouds, rich depth with atmospheric perspective. Friendly, magical, inviting mood. No characters, no text, no logos, no UI. Clean composition with a clear empty central stage.
A sunny Mediterranean coastal cove at golden afternoon. Turquoise crystal-clear shallow water with sparkling reflections, the sea horizon at about 55% of the image height. White limestone cliffs and ancient Greek-style stone arches and columns with magenta bougainvillea flowers stand in the side bands (10%–25% and 75%–90% of the width), continuing simply to the outer edges. A small distant white island with an old temple, small and soft, in the right side band near the horizon. Soft fluffy clouds. From 72% of the height down: sunlit pale limestone terrace tiles; terracotta amphora vases and flowers only in the bottom corners.
[COMPOSITION — TALL PHONES] Vertical portrait 2:3 canvas. The game fills the screen height and crops the sides on tall phones, so only the middle 70% of the width is always visible. Keep the top 18% a calm, simple sky with only soft clouds. Keep the middle 50% of the width, from 20% to 72% of the height, completely empty and calm — open water and sky only, no objects, no structures. Identity elements only in the bands 10%–25% and 75%–90% of the width, not at the extreme edges. Keep the bottom center clear for a cannon and the bottom 5% simple. Slightly soft focus for depth. Eye-level camera, slight low angle.
Use the attached image ONLY as a style and color reference for the environment. Do not copy the tower, the cannon or the UI.
Do not include: towers, blocks, cannon, balls, characters, people, text, letters, numbers, logos, UI, frames, watermarks.
```

**2. akdeniz_front**
```
[ORDINO STYLE BIBLE] (as above)
Isolated foreground props for a Mediterranean coastal game scene on a fully transparent background, portrait 2:3 canvas: on the left, a broken ancient limestone column fragment draped with magenta bougainvillea flowers and green leaves, placed in the band 10%–30% of the width and rising from the bottom to about 45% of the height; on the right, two terracotta amphora vases with a small pot of white and pink flowers, in the band 70%–90% of the width, from the bottom to about 25% of the height. Everything else fully transparent. Warm golden afternoon light from the upper left, soft contact shadows only under the props. Keep the whole middle of the image empty and transparent.
Use the attached image ONLY as a style and color reference. Do not copy the tower, the cannon or the UI.
Do not include: towers, blocks, cannon, balls, characters, people, text, letters, numbers, logos, UI, frames, watermarks, ground plane, sky.
```

**3. akdeniz_card**
```
[ORDINO STYLE BIBLE] (as above)
Square 1:1 hero illustration card for the world "Mediterranean Coast". In the center, an iconic stacked tower made of pale limestone arches, wooden planks and glowing amber and turquoise glass cubes, with a shiny golden sphere hanging inside a stone arch, standing in turquoise shallow water. Background: sunny Mediterranean cove with white cliffs, ancient arches and magenta bougainvillea, soft clouds. Strong rim light, cinematic, very readable at small size. No text, no frame, no UI.
Use the attached image ONLY as a style and color reference.
```

**4–8. Dokular** (§7 şablonu: `Seamless tileable PBR texture, flat orthographic top-down view, even diffuse lighting, no shadows, no perspective, no objects, stylized hand-painted game texture matching a vibrant premium mobile game, 1024x1024, <TANIM>.`)
- `tex_limestone_plinth`: `large smooth pale limestone slabs of a sunlit Mediterranean terrace, warm cream color, subtle weathering and tiny chips, soft joints between slabs`
- `tex_stone`: `warm cream limestone blocks, soft worn edges, subtle cracks, light beige`
- `tex_wood`: `rich brown wooden planks with visible grain, slightly painted, iron bolt holes`
- `tex_crystal_amber`: `glowing amber glass with inner light and subtle internal facets`
- `tex_crystal_cyan`: `glowing turquoise glass with inner light and subtle internal facets`

**Durum (2026-11-20):** 8 görsel üretildi, kalite kontrolünden geçti ve yerleştirildi (`assets/`, Git LFS). Oyunda:
- Arka plan `LevelBackground` (`src/gameplay/world/level_background.gd`): 3D sahnenin **arkasında** CanvasLayer (Environment `background_mode = Canvas`),
  ekran yüksekliğini doldurur, yanlar kırpılır (K-035). Ön katman (`front.png`) **şimdilik kapalı** (`rules.visuals.background_front = ""`): far görselinin
  köşelerinde zaten amfora/çiçek var, ikinci kez ekleyince kalabalıklaşıyordu; paralaks eklenince küçültülüp açılabilir.
- Dünya ortamı `src/gameplay/world/env/akdeniz.tres` (sıcak ambient, glow) + `worlds.akdeniz.light` (güneş rengi).
- Blok ve kaide dokuları `SurfaceTexture` ile nesne uzayında triplanar (UV gerekmez; `rules.visuals.texture_world_scale`).
- Malzeme parlaklığı `rules.visuals.material_looks` (K-038): kristallerde doku rengi `tint` ile doygunlaşır, `emission` ile hafif içten parlar; Altın Küre metalik.
- Kalite notları: far'da kemerler kenara çok yakın (19.5:9'da büyük kısmı kırpılıyor, sorun değil); sol üstteki çiçekler HUD şeridine taşıyor (yazılar okunuyor).
- **Pahlı bloklar ve kaide (Godot'ta prosedürel, Blender değil):** blok ve kaide boyutları bölümden bölüme değişir; sabit bir mesh'i
  ölçeklemek pahları bozar. `ShapeBuilder.bevel_box_mesh` kutu bloklara `rules.visuals.block_bevel` pahı verir (çarpışma kutusu aynı).
  Kaide (`Platform`): pahlı kapak (oyun yüzeyi) + altında içeride, koyulaştırılmış kısa gövde (`rules.visuals.plinth`). İlk deneme
  `pedestal_depth` 4.0 ekranın alt ortasını kaplıyordu → 0.9 + `body_tint` 0.72.
- **Top modeli (Blender):** `tools/blender/make_cannon.py` → `assets/models/cannon/cannon.glb` (kırmızı + altın, tekerlekli).
  İki parça: `Carriage` Yaw ile döner, `Barrel` Pitch ile eğilir; pivot ve Muzzle aynı kaldı (balistik değişmedi).
  Altın düşük metalik (0.35): Canvas arka planda gökyüzü yansıması yok, tam metal altın siyah görünüyordu.
  Yeniden üretmek: `blender -b --python tools/blender/make_cannon.py -- assets/models/cannon/cannon.glb`. Yol: `rules.visuals.cannon_model`.
- Kadraj (top büyük, arkadan, alttan kırpık) **Sena onayı bekliyor** (K-016 top konumu değişirse).
