---
name: ordino-art-prompts
description: Ordino Games için tutarlı görsel üretim promptları yazar (dünya arka planları, ön dekor katmanları, dünya kartları, top ikonları, malzeme dokuları, UI kiti, mağaza görselleri) ve gelen görselleri kalite listesine göre denetleyip doğru klasöre yerleştirir. "prompt yaz", "görsel üret", "arka plan", "ikon", "doku" isteklerinde kullan.
---

# Ordino Görsel Prompt Yazarı

## Önce oku
- `docs/04_GORSEL_URETIM_VE_PROMPTLAR.md` → **Style Bible**, **Composition** bloğu, negatif kısıtlar, dünya renk aileleri, kalite listesi.
- `game_data/worlds.json` → dünyanın id'si, paleti, malzemeleri.
- `docs/referans/` → ilgili referans görsel.

## Karar: Bu varlık AI görseli mi?
`docs/04 §1` tablosuna bak. Bloklar/oyun içi toplar 3D'dir → onlar için **görsel değil, doku** promptu yaz.
Kullanıcı "her taş için prompt" isterse kibarca bunun neden gereksiz olduğunu açıkla ve malzeme dokusu öner.

## Prompt yazma kuralları
1. Promptlar **İngilizce** (görsel modeller daha iyi anlar); açıklama ve talimatlar Sena için **Türkçe**.
2. Yapı: `[ORDINO STYLE BIBLE]` + konu tanımı + (arka plansa) `[COMPOSITION]` + negatif kısıtlar.
3. Görselde **asla yazı/rakam/logo** isteme (Türkçe karakterleri bozar) — yazılar Godot'ta eklenir.
4. Arka planlarda merkez kule alanı **boş**, alt orta top için boş, üst %12 sakin.
5. Referans görsel eklenecekse şu cümleyi ekle: `Use the attached image ONLY as a style and color reference. Do not copy the tower, the cannon or the UI.`
6. Boyut/oran belirt: arka plan 2:3 portre (1024x1536), ikon 1:1 şeffaf, doku 1:1 dikişsiz.
7. Her prompt için **dosya adı ve hedef klasörü** de yaz (ör. `assets/backgrounds/korsan/far.webp`).

## Çıktı formatı (Sena'ya)
```
### <Varlık adı> — <dosya yolu>
Hangi referans görseli ekle: <dosya veya yok>
Model ayarı: <oran/çözünürlük/şeffaflık>
PROMPT:
<kopyalanabilir tek blok prompt>
Kontrol: <bu görsele özel 2-3 madde>
```

## Gelen görselleri işleme (`incoming_art/`)
1. Görseli aç ve `docs/04 §9` kalite listesini uygula; sorunları Türkçe raporla, gerekirse düzeltilmiş prompt ver.
2. Uygunsa yeniden adlandır, WebP/PNG'ye dönüştür, ≤2048 px'e ölçekle, hedef klasöre koy.
3. Godot'ta yer tutucuyu gerçek görselle değiştir; ekran görüntüsü almayı Sena'dan iste ve kompozisyonu doğrula.
