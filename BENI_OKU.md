# Ordino Games — Claude Proje Paketi (Sena için başlangıç rehberi)

## Bu paket ne?
Oyununu Claude ile **adım adım** geliştirmen için hazırlanmış proje iskeleti. Kod yok (henüz) — Claude kodu bu dokümanlara bakarak yazacak.

```
ordino-games/
├── BENI_OKU.md                 ← şu an okuduğun dosya
├── CLAUDE.md                   ← Claude Code'un her oturumda otomatik okuduğu ana talimat
├── ORDINO_TUM_DOKUMAN.txt      ← tüm dokümanların tek dosyada birleşimi (Claude uygulamasındaki Projeye eklemek için; `python tools/build_combined_doc.py` ile üretilir, elle düzenleme)
├── docs/
│   ├── 01_OYUN_TASARIMI_GDD.md      oyun kuralları, dünyalar, toplar, yıldız, ekranlar
│   ├── 02_TEKNIK_MIMARI.md          Godot, tam 3D, klasörler, sistemler, fizik, kayıt
│   ├── 03_KULE_VE_BOLUM_TASARIMI.md kule mantığı, çift kule, zorluk, bölüm üretimi
│   ├── 04_GORSEL_URETIM_VE_PROMPTLAR.md  neyi AI ile üreteceğiz + hazır promptlar
│   ├── 05_EKONOMI_VE_MONETIZASYON.md     altın, mağaza, IAP
│   ├── 06_YOL_HARITASI.md           11 faz, her fazda Claude'a yapıştıracağın prompt
│   ├── 07_OYUN_HISSI_JUICE.md       tatmin hissi: efekt, ses, titreşim
│   ├── 08_KARAR_GUNLUGU.md          alınan ve bekleyen kararlar
│   └── referans/                    senin 6 konsept görselin
├── game_data/                  ← ⚙️ OYUN KURALLARI (sonradan değiştireceğin yer)
│   ├── rules.json  balls.json  materials.json  shapes.json
│   ├── worlds.json  difficulty.json  economy.json
│   └── levels/w01_akdeniz/  (2 örnek bölüm)
├── tools/
│   ├── validate_game_data.py   JSON'larda hata var mı kontrol eder
│   └── economy_sim.py          altın dengesi raporu
└── .claude/skills/             ← Claude'a özel 4 yetenek (/ordino-level-designer vb.)
```

## Kuralları nasıl değiştiririm?
Örnekler — hepsi tek satır değişiklik:
| İstek | Dosya → alan |
|---|---|
| Alev topu 5. bölümde açılsın | `balls.json` → fire → `unlock.level_id: "w01_l05"` |
| Açılınca 5 hediye versin | `balls.json` → fire → `gift_on_unlock: 5` |
| 3 yıldız 50 altın versin | `economy.json` → `rewards.stars."3": 50` |
| Tüm oyun %10 kolay olsun | `difficulty.json` → `global_multiplier: 0.9` |
| Her bölüm 4 gülle | `rules.json` → `shots.default_per_level: 4` |
| Korsan dünyası 15 yıldızla açılsın | `worlds.json` → korsan → `unlock_stars_required: 15` |

Ya da Claude Code'a Türkçe söyle: *"Alev topunu 5. bölümde aç, 5 hediye ver, sonra denge raporunu göster."* → Claude `/ordino-balance` ile yapar.
Değişiklikten sonra: `python3 tools/validate_game_data.py`

## Başlamak için 5 adım
1. Godot 4.7.x (stable, standart sürüm) kur. VS Code'da Claude Code eklentin hazır.
2. GitHub'da özel repo aç, bu klasörün içeriğini repo köküne koy, ilk commit.
3. VS Code'da klasörü aç → Claude Code panelini aç.
4. `docs/06_YOL_HARITASI.md` → **FAZ 0** promptunu yapıştır.
5. Claude uygulamasında bir **Proje** aç, `ORDINO_TUM_DOKUMAN.txt` + referans görselleri ekle → tasarım sohbetleri ve görsel promptları için orayı kullan.
