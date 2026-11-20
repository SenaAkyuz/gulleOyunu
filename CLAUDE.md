# CLAUDE.md — Ordino Games: "Physics. Impact. Satisfaction."

> Bu dosya Claude Code'un bu repoda her oturumda otomatik okuduğu ana talimat dosyasıdır.
> Kısa tutulur; ayrıntılar `docs/` altındadır. Bir işe başlamadan önce ilgili dokümanı oku.

## 1. Proje tek cümlede
Mobil (iOS + Android), fizik tabanlı bir **top atarak kule yıkma** bulmaca oyunu. Oyuncu ekranın altındaki
**topla (cannon)** nişan alır, sınırlı sayıda gülle ile kuleyi yıkıp **blokların %80'ini platformdan düşürür** ("masayı temizle", K-018);
kuleye gömülü **Altın Küre**'yi de düşürürse **jackpot** altını kazanır.
8 dünya × 10 bölüm (şimdilik), 6 özel top, yıldız → altın ekonomisi, altın → top satın alma, gerçek para → altın.
Rakip referansı: *Smash Away!* (Oakever). Hedefimiz: görsel olarak çok daha zengin, "juicy", tatmin edici yıkım.

## 2. Kullanıcı (proje sahibi) hakkında
- Proje sahibi: **Sena** (Ordino). Türkçe konuşur → **Sena ile her zaman Türkçe konuş.**
- Kod, değişken adları, JSON anahtarları, commit mesajları **İngilizce**; oyuncuya görünen metinler **TR** (sonra EN).
- Sena yazılımcı olmayabilir: her adım sonunda **ne yaptığını, nasıl test edeceğini (hangi tuş / hangi sahne)** sade Türkçe ile anlat.
- Tasarım kararlarında **öneri sun, gerekçesini söyle, karar Sena'nın.** Kararlar `docs/08_KARAR_GUNLUGU.md`'ye yazılır.

## 3. Teknik temel (karar verildi — değiştirmek için Sena'ya sor)
| Konu | Karar |
|---|---|
| Motor | **Godot 4.7.x stable** (beta sürüm kullanma) |
| Dil | **GDScript** (statik tipli: `var hp: float`, `func f() -> void`) — C# kullanma (iOS export riski) |
| Görünüm | **Tam 3D** (K-002): 3D bloklar + 3D fizik, **eksen kilidi yok**; bloklar her eksende döner/devrilir, kuleler x-y-z derinlikli kurulur (Smash Away tarzı). Arka plan AI ile üretilmiş 2D katmanlar |
| Fizik | Jolt (Godot 4.6+ varsayılan 3D). Bloklarda `axis_lock_*` **kullanılmaz**. "Düştü" kuralı: ağırlık merkezinin (x,z) izdüşümü platform dışında **veya** `fall_kill_y` altında (`rules.physics.edge_rule`) |
| Kamera | Perspektif, kuleye yukarıdan eğik, varsayılan **sabit**; değerler `rules.camera`. v1 sabit, kamera döndürme v2 (S-007); her keystone bu açıdan görünür olmalı |
| Renderer | Mobile renderer |
| Ekran | **Portre 1080×1920** (bkz. karar günlüğü K-003) |
| Veri | Tüm oyun kuralları `game_data/*.json` içinde. **Koda sayı gömme (magic number yasak).** |
| Test | GUT (Godot Unit Test) + `tools/` altında Python doğrulayıcılar |
| Sürüm kontrolü | git; görseller/ses için Git LFS |

## 4. Altın kurallar (her zaman uy)
1. **Veri odaklı tasarım:** Top özellikleri, açılma koşulları, fiyatlar, yıldız ödülleri, zorluk eğrisi, malzeme dayanıklılığı
   → hepsi `game_data/` JSON'larında. Kod sadece okur. Yeni bir ayar gerekiyorsa önce JSON'a anahtar ekle, sonra kodu yaz.
2. **JSON'u değiştirdikten sonra** `python3 tools/validate_game_data.py` çalıştır. Hata varsa düzeltmeden bitirme.
3. **Küçük adım:** Her görev = çalışan, test edilebilir küçük bir artım. Büyük işte önce **plan modu** ile plan çıkar, Sena onaylasın.
4. **Mimariyi koru:** Sistemler birbirini doğrudan çağırmaz; `EventBus` sinyalleri ve autoload servisleri üzerinden konuşur (bkz. `docs/02_TEKNIK_MIMARI.md`).
5. **Fizik kuralları:** Bloklar uyuyarak (sleeping) doğar; ilk atışa kadar kule kıpırdamaz. Top CCD (continuous collision) kullanır.
6. **Performans bütçesi (S-008):** Ekranda aynı anda ≤ 120 aktif RigidBody (Faz 1'de orta segment Android'de ölçülür), ≤ 4 aktif GPUParticles emitter patlaması. Parçalar havuzdan (pool) gelir.
7. **Juice her şeydir:** Her darbe = ses + parçacık + (gerekirse) ekran sarsıntısı + titreşim. Bkz. `docs/07_OYUN_HISSI_JUICE.md`.
8. **Dokümanı güncel tut:** Mimari/kural değiştiyse ilgili `docs/` dosyasını da aynı committe güncelle.
9. **Asla** gerçek ödeme/IAP kodunu test anahtarı olmadan çalıştırma; IAP her zaman `IAPService` arayüzünün arkasında.
10. Emin olmadığında **sor**. Tahminle oyun kuralı uydurma; uydurman gerekiyorsa `"_TODO_SENA"` notu bırak.

## 5. Doküman haritası (ilgili işe başlamadan oku)
| Dosya | Ne zaman okunur |
|---|---|
| `docs/01_OYUN_TASARIMI_GDD.md` | Oyun kuralları, dünyalar, toplar, yıldız, akış |
| `docs/02_TEKNIK_MIMARI.md` | Kod yazmadan önce: klasör yapısı, autoload'lar, sahneler, fizik, kayıt |
| `docs/03_KULE_VE_BOLUM_TASARIMI.md` | Bölüm/kule üretirken veya zorluk ayarlarken |
| `docs/04_GORSEL_URETIM_VE_PROMPTLAR.md` | Görsel/prompt üretirken, asset entegre ederken |
| `docs/05_EKONOMI_VE_MONETIZASYON.md` | Altın, mağaza, IAP, reklam |
| `docs/06_YOL_HARITASI.md` | Şu an hangi fazdayız, sıradaki adım ne |
| `docs/07_OYUN_HISSI_JUICE.md` | VFX, ses, kamera, titreşim, animasyon |
| `docs/08_KARAR_GUNLUGU.md` | Alınmış/açık kararlar |
| `docs/referans/` | Sena'nın temsili konsept görselleri (stil referansı) |
| `game_data/` | Tüm ayarlanabilir oyun verisi |

## 6. Proje skill'leri (`.claude/skills/`)
- `/ordino-level-designer` — yeni bölüm/kule tasarla, JSON yaz, doğrula.
- `/ordino-art-prompts` — stil kılavuzuna uygun görsel üretim promptları yaz.
- `/ordino-balance` — ekonomi/zorluk dengesini analiz et ve ayarla.
- `/ordino-game-feel` — bir özelliğin "juice" kontrol listesini uygula/denetle.

Üçüncü taraf skill'ler (sabit sürüm, Apache-2.0, kaynak: gamedev-skills/awesome-gamedev-agent-skills @ c6ca6c4; lisans `.claude/skills/_third_party/`):
`godot-gdscript`, `godot-physics`, `godot-3d-essentials`, `godot-signals-groups`, `godot-gdscript-headless-testing`,
`physics-tuning`, `godot-ui-control`, `game-feel`, `godot-shaders`, `godot-export`.
Üçüncü taraf eklenti: **GUT 9.7.1** (Godot 4.7 sürümü, `addons/gut/`, MIT lisansı `addons/gut/LICENSE.md`), değiştirilmeden kopyalandı.

Üçüncü taraf skill'ler yardımcıdır; çelişkide CLAUDE.md, docs/ ve ordino-* skill'leri önceliklidir. game-feel ile ordino-game-feel çakışırsa ordino-game-feel geçerli.

## 7. Komutlar
```bash
# Oyun verisini doğrula
python3 tools/validate_game_data.py
# Ekonomi simülasyonu (kaç bölümde kaç altın kazanılıyor, top fiyatları erişilebilir mi)
python3 tools/economy_sim.py
# Godot testleri (GUT 9.7.1, addons/gut, MIT; ayarlar .gutconfig.json → res://tests, test_*.gd)
# Taze checkout'ta önce: godot --headless --path . --import
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit   # çıkış kodu 0 = hepsi geçti (--fixed-fps: her kare 1 fizik adımı, CPU hızında; ~30 sn)
# Bölüm simülasyonu (docs/03 §8.1): godot --headless --fixed-fps 60 --path . -s src/tools/sim/sim_cli.gd -- --world akdeniz
```

## 8. Mevcut durum
- **Faz:** 1 — Gri Kutu **tamam** (2026-11-19). **Faz 2 — Veri omurgası ve kayıt tamam** (2026-11-19). **Faz 3 — kule şablonları, generator, bölüm editörü sürüyor** (11 adımlık plan onaylandı 2026-11-19; bkz. `docs/06_YOL_HARITASI.md`). Her faz bitince bu satırı güncelle.
- Faz 1 çıktısı: L01 oynanır (tap_target + drag_release, sürekli atış K-023), hakem/doluluk çubuğu/yıldız/jackpot, hasar, sarsıntı + kıvılcım, Dev Panel (F1), stres testi (P).
  Dev tuşları: G alan · Boşluk uyandır · Tab seç · Oklar it · H hp · R baştan · N/B sonraki/önceki bölüm · F1 panel · P stres · F12 ekran görüntüsü.
- Faz 2 çıktısı: `SaveManager` (sürümlü, atomik, bozuk kayda dayanıklı `user://save.json`), `Economy`, `Progress` (ödül + açılmalar), `Inventory`, `ConfigValidator`; HUD'da altın + en iyi yıldız + kazanılan altın; Dev Panel'de "Kaydı sıfırla"; GUT testleri (`tests/`).
- Açık: Android performans ölçümü (S-008), tutorial elinin çizimi, hit-stop + konfeti (Faz 8).
