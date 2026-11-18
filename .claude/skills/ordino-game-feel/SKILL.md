---
name: ordino-game-feel
description: Ordino Games'te bir özelliğin oyun hissini (juice) uygular veya denetler - hit-stop, kamera sarsıntısı, parçacık, malzeme sesleri, titreşim, ağır çekim, UI animasyonları, özel top efektleri. "daha tatmin edici yap", "juice", "efekt", "his", "VFX", "ses ekle" isteklerinde kullan.
---

# Ordino Oyun Hissi (Juice)

## Önce oku
`docs/07_OYUN_HISSI_JUICE.md` ve `game_data/rules.json → feel`, `quality`.

## Adımlar
1. Hedef özelliği belirle (ör. "Buz Topu çarpması", "sonuç ekranı").
2. `docs/07 §8` kontrol listesini madde madde uygula; eksikleri tablo halinde göster: *Görsel · Ses · Titreşim · Zamanlama · Kalite seviyesi*.
3. Uygularken:
   - Efektleri `EventBus` sinyallerine bağla (ör. `block_broken` → FX/Audio/Haptics dinler). Gameplay koduna efekt kodu gömme.
   - Tüm şiddet/süre değerleri `rules.json → feel` altında; yeni değer gerekiyorsa oraya ekle ve validator'ı çalıştır.
   - Parçacıklar `FxPool`'dan; `quality.levels[*].particles_mult` uygula.
   - Ses: pitch ±%5, aynı karede aynı ses ≤ 3, voice limit 8.
   - Titreşim `Haptics` servisinden, ayarlarda kapalıysa hiç çağrılmaz.
4. Performans: değişiklik sonrası en kalabalık bölümde FPS'yi ölç (Godot Monitor), 60 FPS altına düşerse kalite seviyesine göre kıs.
5. Sena'ya test talimatı: hangi bölümde, neye bakmalı, "önce/sonra" farkı ne.

## Altın kural
Abartma sınırı: ekran sarsıntısı oyuncunun nişanını bozmamalı; nişan alırken (`AIMING` durumunda) sarsıntı 0.
