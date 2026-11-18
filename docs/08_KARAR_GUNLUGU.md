# 08 — Karar Günlüğü

> Her önemli karar buraya yazılır: kim, ne zaman, neden. Açık sorular da burada tutulur.
> Format: `K-NNN | Tarih | Karar | Gerekçe | Durum (Önerildi / Onaylandı / Değişti)`

## Alınan / önerilen kararlar
| No | Tarih | Karar | Gerekçe | Durum |
|---|---|---|---|---|
| K-001 | 2026-11-18 | Motor: **Godot 4.7.x stable**, GDScript | Metin tabanlı sahneler Claude ile verimli; ücretsiz; mobil IAP eklentileri 4.5.2/4.6 ile iyileşti | Onaylandı |
| K-002 | 2026-11-18 | **Tam 3D**: eksen kilidi yok; bloklar her eksende döner/devrilir, platformdan her yöne düşer; kuleler x-y-z derinlikli (Smash Away tarzı); arka plan AI 2D. Kenar kuralı: ağırlık merkezi platform dışında → düştü | Sena tam 3D görünümü istiyor (önceki öneri: XY'ye kilitli 2.5D) | Değişti |
| K-003 | 2026-11-18 | Ekran **portre 1080×1920** | Tek elle oynanış, tür standardı; level map 2×4 kaydırmalı listeye uyarlanır | Onaylandı |
| K-004 | 2026-11-18 | Tüm kurallar `game_data/*.json`; koda sayı gömülmez | Sena kuralları kolayca değiştirebilsin | Onaylandı (Sena'nın isteği) |
| K-005 | 2026-11-18 | Başlangıç topu **Ağır Top**, sınırsız | Sena'nın isteği | Onaylandı |
| K-006 | 2026-11-18 | Özel toplar: açılınca hediye (öneri 3), sonra altınla paket | Sena'nın isteği; sayılar `balls.json` | Onaylandı (sayılar taslak) |
| K-007 | 2026-11-18 | Yıldız → altın: 3★ > 2★ > 1★; tekrar oynamada azaltılmış ödül | Sena'nın isteği + farm önleme | Onaylandı (sayılar taslak) |
| K-008 | 2026-11-18 | Bloklar 3D mesh (Blender scripti) + AI doku; arka planlar/ikonlar/UI AI görsel | Her taş için prompt gereksiz | Onaylandı |
| K-009 | 2026-11-18 | Bölümler: şablon + generator + simülasyon + elle cila; yayında `baked` | Çeşitlilik + kontrol | Onaylandı |
| K-010 | 2026-11-18 | Varsayılan kazanma: **Altın Küre'yi düşür** | Görsellerdeki altın küre; net hedef | Değişti → K-018 |
| K-011 | 2026-11-18 | Nişan varsayılanı **tap_target**; sürükleme ince ayar için | Basit "seç ve at" kontrolü (S-002) | Onaylandı |
| K-012 | 2026-11-18 | v1'de tek para birimi: **altın**; elmas sistemi hazır ama kapalı | Denge sadeliği, casual oyuncu (S-001) | Onaylandı |
| K-013 | 2026-11-18 | v1'de yalnızca **ödüllü reklam**, interstitial yok | Retention + çocuk oyuncu politikaları (S-003) | Onaylandı |
| K-014 | 2026-11-18 | İlk sürüm **TR + EN**; tüm metinler baştan çeviri tablosunda | Global mağaza (S-004) | Onaylandı |
| K-015 | 2026-11-18 | iOS build ve yayın **Codemagic** (bulut macOS) ile | Sena'nın Codemagic hesabı var, Mac gerekmez (S-005) | Onaylandı |
| K-018 | 2026-11-18 | **Ana hedef "masayı temizle"** (`clear_percent`, K-010'un yerine): blok **hacminin** %80'i platformdan düşünce bölüm kazanılır (`rules.objective_defaults`: `type`, `clear_percent_target = 0.8`, `clear_measure = "volume"` / `"count"`); Altın Küre ve joint'ler orana dahil değil; ekranda doluluk çubuğu; otomatik final temizliği yok. **Altın Küre = jackpot:** `clear_percent` bölümlerinde kule içine/kemer altına/tepeye gömülü; düşerse büyük altın (`economy.rewards.core_jackpot_gold`, taslak 20) + ağır çekim + konfeti; yıldızı etkilemez. `drop_core` yalnızca dünya başına 1–2 bölüm (zincire asılı küre, boss); küre korunaklı, doğrudan tek atışla düşmez. Yıldızlar değişmedi (kalan gülle, `rules.stars`). Zorluk: daha çok/ağır blok, dağınık/ikiz kuleler, daha az gülle, daha derine gömülü küre | Smash Away'in "masayı temizle" tatmini ana döngü olur; küre ustalık ve tekrar oynama motivasyonu veren ikincil hedef | Onaylandı |

## Açık sorular (Sena karar verecek)
| No | Soru | Öneri | Durum |
|---|---|---|---|
| S-001 | Elmas (ikinci para) olacak mı? | v1'de hayır, sistem hazır | Kapandı → K-012 |
| S-002 | Nişan modu: dokun-hedefle mi, sürükle-bırak mı? | tap_target varsayılan | Kapandı → K-011 |
| S-003 | Zorla gösterilen reklam? | v1'de yok, sadece ödüllü | Kapandı → K-013 |
| S-004 | Oyun dili: TR + EN ilk sürümde mi? | Evet | Kapandı → K-014 |
| S-005 | Mac erişimi var mı? (iOS build için şart) | Codemagic bulut build | Kapandı → K-015 |
| S-006 | Oyun adı: "Ordino Games" yayıncı adı mı, oyun adı mı? | Faz 11'e kadar çalışma adı kullanılır | Ertelendi |
| S-007 | Kamera: oyuncu kuleyi döndürebilsin mi? | **Sena:** v1'de kamera sabit (çapraz, ~20° yukarıdan, `rules.camera`). Tasarım kuralı: her keystone varsayılan kamera açısından görünür olmalı (`docs/03` §4 kural 3). Kamera döndürme v2'de değerlendirilir. | Önerildi |
| S-008 | Performans bütçesi tam 3D'de aynı mı kalsın? | **Sena:** ≤120 aktif gövde olarak kalır; Faz 1'de orta segment Android cihazda ölçülür, gerekirse revize edilir. | Önerildi |
