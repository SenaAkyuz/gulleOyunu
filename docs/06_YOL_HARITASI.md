# 06 — Yol Haritası (adım adım, Claude ile)

> Her faz: **Amaç → Claude Code'a yapıştırılacak prompt → Bitti kriteri (Sena test eder)**.
> Kural: Bir faz bitmeden sonrakine geçme. Her faz sonunda `git commit` ve `CLAUDE.md §8 Mevcut durum` güncellenir.
> Büyük fazlarda önce **plan modu** (Claude Code'da Shift+Tab ile) → planı oku → onayla → uygulat.

---

## Nerede hangi Claude?
| İş | Araç | Neden |
|---|---|---|
| Kod yazma, dosya oluşturma, test çalıştırma | **Claude Code — VS Code eklentisi** (veya terminal) | Repo'daki dosyaları doğrudan görür/değiştirir, `CLAUDE.md` ve skill'leri otomatik yükler |
| Tasarım tartışması, görsel değerlendirme, prompt üretimi, ekran görüntüsü yorumlama | **Claude uygulaması** (claude.ai / masaüstü) — bir **Proje** aç, `ORDINO_TUM_DOKUMAN.txt`'yi proje bilgisine ekle | Uzun sohbet, görsel analizi, karar verme |
| Bölüm tasarlama, denge, prompt | İkisinde de: Claude Code'da `/ordino-level-designer`, `/ordino-balance`, `/ordino-art-prompts` | Skill'ler repo içinde |

**Altın ipuçları (Claude Code):**
- Her yeni büyük işte yeni oturum aç; bağlam şişince `/compact`.
- "Önce planla, kod yazma" de → plan modunu kullan.
- Bir şey bozulursa: hata mesajını ve Godot çıktısını **olduğu gibi** yapıştır.
- Her adımdan sonra: "Değişiklikleri özetle ve nasıl test edeceğimi söyle."
- Commit'i Claude'a yaptırabilirsin: "Testler geçtiyse commit at."

---

## FAZ 0 — Kurulum (1 gün)
**Sena yapar:**
1. Godot **4.7.x stable** indir (godotengine.org) → standart sürüm (GDScript, .NET değil).
2. VS Code + Claude Code eklentisi (var). Git kurulu olsun; GitHub'da özel (private) repo aç: `ordino-games`.
3. Bu paketi repo köküne kopyala (`CLAUDE.md`, `docs/`, `game_data/`, `tools/`, `.claude/`).
4. Blender 4.x indir (Faz 7'ye kadar şart değil).
5. Python 3 kurulu mu kontrol et: `python3 --version`.

**Claude Code'a ilk prompt:**
```
CLAUDE.md'yi ve docs/ altındaki tüm dokümanları oku. Sonra:
1) Anladığın oyunu 10 maddede özetle,
2) Dokümanlar arasında çelişki veya eksik gördüğün yerleri listele,
3) Faz 1 için plan modu ile bir uygulama planı çıkar. Henüz kod yazma.
```
**Bitti kriteri:** Claude'un özeti doğru, çelişkiler `08_KARAR_GUNLUGU.md`'ye işlendi, `python3 tools/validate_game_data.py` → OK.

---

## FAZ 1 — Fizik prototipi "Gri Kutu" (3–5 gün) ⭐ en kritik faz
**Amaç:** Görsel yok. Sadece: top + ağır gülle + 3 malzeme (taş, ahşap, kristal) + 1 kule + Altın Küre. **Eğlenceli mi?**
```
Faz 1'i uygula (docs/02 ve docs/03'e uy):
- Godot 4.7 projesi oluştur (Mobile renderer, portre 1080x1920, Jolt).
- Autoload: EventBus, GameConfig (game_data JSON'larını yükler).
- block.tscn: RigidBody3D, tam 3D (eksen kilidi yok), uyuyarak doğar, kenar kuralı rules.physics.edge_rule, materials.json'dan yoğunluk/hp okur. Hasar modeli docs/02 §6.3.
- ball.tscn (ağır top), cannon.tscn (dokun-hedefle ve sürükle-bırak; rules.aim.mode), noktalı yörünge önizlemesi.
- Basit platform, KillZone, Altın Küre, LevelReferee (clear_percent + doluluk çubuğu + jackpot küre + yıldız: rules.stars; K-018).
- game_data/levels/w01_akdeniz/w01_l01.json'u yükleyip çalıştır.
- Basit FX: çarpmada küçük kamera sarsıntısı + kıvılcım parçacığı.
- Dev panel (F1): yerçekimi, top hızı, malzeme hp canlı ayar.
Bitince bana masaüstünde nasıl çalıştıracağımı ve neyi test etmem gerektiğini Türkçe anlat.
```
**Bitti kriteri:** F5 ile oyun açılıyor; atış hissi iyi; kule ilk atışa kadar kıpırdamıyor; blokların %80'i düşünce "KAZANDIN ⭐⭐⭐" yazıyor, küre de düşerse jackpot kutlaması;
Sena 10 kez oynayıp "eğlenceli" diyor. Değilse **Faz 1'de kal** ve hissi düzelt (top hızı, kütle, kamera).

## FAZ 2 — Veri omurgası ve kayıt (2–3 gün)
```
Faz 2: GameConfig'i tam şema doğrulamalı yap, Progress/Economy/Inventory/SaveManager autoload'larını yaz (docs/02 §4.1, §8),
GUT kur ve bu servisler için birim testleri yaz. tools/validate_game_data.py ile uyumlu kal.
```
**Bitti:** Testler yeşil; oyunu kapat-aç → ilerleme ve altın korunuyor.

## FAZ 3 — Kule şablonları, generator, bölüm editörü (5–7 gün)
```
Faz 3: docs/03'e göre shapes.json şekillerini (kemer compound collider dahil) ve 6 temel şablonu
(stack_pyramid, twin_pillars, arch_shrine, staircase, domino_row, truss_bridge) uygula. Generator'ı difficulty.json'a bağla,
support_check yaz. Headless simülasyon aracını (one_shot_solve_rate vb.) yaz. Basit bir Godot editör eklentisi ile bölüm editörü yap.
```
**Bitti:** Editörde "Üret" → farklı ama dengeli kuleler; "Simüle Et" → metrikler; Dünya 1'in 10 bölümü JSON olarak hazır.

## FAZ 4 — Oyun döngüsü ve menüler (4–5 gün)
```
Faz 4: Ana menü, dünya haritası (8 kart, kilit/yıldız), dünya içi bölüm seçimi (10 düğüm + boss), HUD (level, gülle göstergesi, ayar),
sonuç ekranı (yıldız + altın uçuş animasyonu), başarısız ekranı (+1 gülle), ayarlar. SceneRouter ile geçişler. Görseller placeholder.
```
**Bitti:** Uçtan uca: menü → dünya 1 → 10 bölüm → yıldız/altın kaydediliyor → dünya 2 kilidi yıldızla açılıyor.

## FAZ 5 — Özel toplar (5–7 gün)
```
Faz 5: BallBehavior strateji desenini kur ve 5 özel topu uygula (fire, saw, ice, electric, gravity) — balls.json parametreleriyle.
materials.json bayrakları (flammable, cuttable, conductive, freezable, thermal_shock) ile etkileşim. Joint'li bloklar (halat/zincir/sarmaşık).
Top seçici UI, açılma koşulları, tanıtım kartı, hediye adetleri. Her top için 1 test bölümü.
```
**Bitti:** Her top görselde yazan işi yapıyor ve "vay!" dedirtiyor; açılma kuralı JSON'dan değişince oyunda değişiyor.

## FAZ 6 — Ekonomi ve mağaza (3 gün)
```
Faz 6: economy.json ödül formülü (docs/05 §2), mağaza ekranı (Toplar sekmesi, Altın sekmesi MockIAP ile), +1 gülle,
tools/economy_sim.py çıktısını kontrol et ve raporla.
```
**Bitti:** Altın kazan → top al → kullan döngüsü çalışıyor; sim raporu hedef aralıkta.

## FAZ 7 — Görsel üretim ve entegrasyon (1–2 hafta, paralel ilerleyebilir)
```
/ordino-art-prompts ile Dünya 1 (Akdeniz) için tam prompt setini üret: arka plan (far/front), kart, kaide dokusu, gerekli malzeme dokuları.
Ayrıca tools/blender/generate_blocks.py yaz: shapes.json'daki tüm şekiller için bevel'li mesh + Cell Fracture kırık sürümleri, .glb export.
```
Sena görselleri üretir → `incoming_art/` → Claude yerleştirir. Önce **1 dünyayı tam bitir** (dikey dilim / vertical slice), sonra diğer 7.
**Bitti:** Dünya 1 referans görseller kalitesinde görünüyor, 60 FPS (orta Android).

## FAZ 8 — Oyun hissi (juice), ses, VFX (1 hafta)
```
/ordino-game-feel ile docs/07 kontrol listesini tüm sistemlere uygula: hit-stop, kamera sarsıntısı, ağır çekim final, parçacıklar,
malzeme bazlı sesler, titreşim, UI animasyonları, altın sayacı. Kalite seviyeleri (low/medium/high).
```

## FAZ 9 — 80 bölüm üretimi ve denge (2 hafta)
```
/ordino-level-designer ile Dünya N'nin 10 bölümünü docs/03 ritmine göre üret: her bölüm için 5 aday, sim metrikleri tablosu, en iyiyi öner.
```
Sena her dünyayı oynar, notlar → Claude düzeltir. Arkadaşlarla **playtest** (en az 5 kişi, hiç yardım etmeden izle).

## FAZ 10 — IAP, reklam, analitik, uzaktan ayar (1 hafta)
```
Faz 10: IAPService için Android (Google Play Billing) ve iOS (StoreKit) eklentilerini güncel Godot 4.7 uyumlu sürümlerle araştır, öner,
kur. AdsService (ödüllü reklam). Analytics olayları (docs/05 §7). Remote config override (rules/economy/difficulty).
```

## FAZ 11 — Yayın (1 hafta)
- Android: Play Console → iç test (internal testing) → kapalı test → üretim.
- iOS: Codemagic (bulut macOS, K-015) → App Store Connect (Sena: Admin) → TestFlight → inceleme.
- Mağaza görselleri, tanıtım videosu, gizlilik politikası, yaş derecelendirmesi, veri güvenliği formu.

---

## Zaman özeti (tek kişi + Claude, tahmini)
Faz 0–1: 1 hafta · Faz 2–4: 2 hafta · Faz 5–6: 1.5 hafta · Faz 7–8: 2–3 hafta · Faz 9: 2 hafta · Faz 10–11: 2 hafta → **~10–12 hafta** ilk sürüm.
