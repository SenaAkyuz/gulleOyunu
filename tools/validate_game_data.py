#!/usr/bin/env python3
"""Ordino Games - game_data dogrulayici.

Kullanim:  python3 tools/validate_game_data.py
Hata varsa cikis kodu 1 doner. JSON degistirdikten sonra mutlaka calistir.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "game_data"
errors: list[str] = []
warnings: list[str] = []


def load(name: str) -> dict:
    path = ROOT / name
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        errors.append(f"{name}: dosya yok")
    except json.JSONDecodeError as e:
        errors.append(f"{name}: JSON hatasi satir {e.lineno}: {e.msg}")
    return {}


rules = load("rules.json")
balls_doc = load("balls.json")
materials = load("materials.json").get("materials", {})
shapes = load("shapes.json").get("shapes", {})
worlds = load("worlds.json").get("worlds", [])
difficulty = load("difficulty.json")
economy = load("economy.json")

VALID_FLAGS = {"flammable", "cuttable", "conductive", "freezable", "shatter",
               "thermal_shock", "objective", "joint", "unbreakable"}
VALID_UNLOCK = {"start", "level_cleared", "levels_cleared_count", "world_completed", "stars_total"}
VALID_OBJECTIVES = {"drop_core", "clear_percent", "shatter_crystals", "drop_all_cores"}
VALID_ROLES = {r["role"] for r in difficulty.get("rhythm", [])}
VALID_AIM = {"tap_target", "drag_release"}
VALID_EDGE_RULES = {"com_outside_platform"}
VALID_COLLIDERS = {"box", "sphere", "cylinder", "convex"}
VALID_KEEP_ASPECT = {"width", "height"}
VALID_ARC = {"low", "high"}
VALID_ON_MISS = {"ignore"}
VALID_CLEAR_MEASURE = {"volume", "count"}
CORE_OBJECTIVES = {"drop_core", "drop_all_cores"}


def is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def is_vec3(v) -> bool:
    return isinstance(v, list) and len(v) == 3 and all(is_num(c) for c in v)


# --- rules (tam 3D, K-002) ---
if rules.get("aim", {}).get("mode") not in VALID_AIM:
    errors.append(f"rules.aim.mode gecersiz: {rules.get('aim', {}).get('mode')}")
phys = rules.get("physics", {})
if phys.get("axis_locks", False):
    errors.append("rules.physics.axis_locks true olamaz (K-002: tam 3D)")
if phys.get("edge_rule") not in VALID_EDGE_RULES:
    errors.append(f"rules.physics.edge_rule gecersiz: {phys.get('edge_rule')}")
cam = rules.get("camera")
if not cam:
    errors.append("rules.camera eksik")
else:
    for key in ("fov_deg", "pitch_deg", "yaw_deg", "distance", "look_at_height"):
        if not is_num(cam.get(key)):
            errors.append(f"rules.camera.{key} sayi olmali")
    if cam.get("keep_aspect") not in VALID_KEEP_ASPECT:
        errors.append(f"rules.camera.keep_aspect gecersiz: {cam.get('keep_aspect')} ({VALID_KEEP_ASPECT})")
aim = rules.get("aim", {})
if aim.get("arc") not in VALID_ARC:
    errors.append(f"rules.aim.arc gecersiz: {aim.get('arc')} ({VALID_ARC})")
if aim.get("on_miss") not in VALID_ON_MISS:
    errors.append(f"rules.aim.on_miss gecersiz: {aim.get('on_miss')} ({VALID_ON_MISS})")
if not is_num(aim.get("preview_dot_interval_sec")) or aim.get("preview_dot_interval_sec") <= 0:
    errors.append("rules.aim.preview_dot_interval_sec pozitif sayi olmali")
if not is_vec3(rules.get("cannon", {}).get("position")):
    errors.append("rules.cannon.position [x, y, z] olmali")
if not is_num(phys.get("spawn_edge_inset")) or phys.get("spawn_edge_inset") < 0:
    errors.append("rules.physics.spawn_edge_inset 0 veya pozitif sayi olmali")
crack = rules.get("feel", {}).get("crack_hp_ratio")
if not is_num(crack) or not 0 < crack < 1:
    errors.append("rules.feel.crack_hp_ratio 0 < x < 1 olmali")
obj_def = rules.get("objective_defaults", {})
# K-018: varsayilan hedef clear_percent, Altin Kure jackpot
if obj_def.get("type") not in VALID_OBJECTIVES:
    errors.append(f"rules.objective_defaults.type gecersiz: {obj_def.get('type')}")
if not is_num(obj_def.get("clear_percent_target")) or not 0 < obj_def["clear_percent_target"] <= 1:
    errors.append("rules.objective_defaults.clear_percent_target 0 < x <= 1 olmali")
if not isinstance(obj_def.get("broken_counts_as_cleared"), bool):
    errors.append("rules.objective_defaults.broken_counts_as_cleared true/false olmali")
if obj_def.get("clear_measure") not in VALID_CLEAR_MEASURE:
    errors.append(f"rules.objective_defaults.clear_measure gecersiz: {obj_def.get('clear_measure')} ({VALID_CLEAR_MEASURE})")
if obj_def.get("core_shape") not in shapes:
    errors.append(f"rules.objective_defaults.core_shape '{obj_def.get('core_shape')}' shapes.json'da yok")
if obj_def.get("core_material") not in materials:
    errors.append(f"rules.objective_defaults.core_material '{obj_def.get('core_material')}' materials.json'da yok")
for key in ("thickness", "friction", "bounce"):
    if not is_num(rules.get("platform", {}).get(key)):
        errors.append(f"rules.platform.{key} sayi olmali")
guide = rules.get("dev", {}).get("play_area_guide", {})
if not (is_vec3(guide.get("min")) and is_vec3(guide.get("max"))):
    errors.append("rules.dev.play_area_guide min/max [x, y, z] olmali")
if not is_num(rules.get("dev", {}).get("nudge_impulse")) or rules["dev"]["nudge_impulse"] <= 0:
    errors.append("rules.dev.nudge_impulse pozitif sayi olmali")
stress = rules.get("dev", {}).get("stress_block_count")
if not isinstance(stress, int) or isinstance(stress, bool) or stress <= 0:
    errors.append("rules.dev.stress_block_count pozitif tam sayi olmali")

# --- shapes (3D) ---
for sid, s in shapes.items():
    size = s.get("size")
    if not is_vec3(size) or min(size) <= 0:
        errors.append(f"shapes.{sid}: size [x, y, z] (3 pozitif sayi) olmali")
    if "depth" in s:
        warnings.append(f"shapes.{sid}: 'depth' eski 2.5D alani; derinlik size[2]'de")
    if not s.get("colliders"):
        errors.append(f"shapes.{sid}: colliders bos")
    for i, c in enumerate(s.get("colliders", [])):
        ctype = c.get("type")
        where = f"shapes.{sid}.colliders[{i}]"
        if ctype not in VALID_COLLIDERS:
            errors.append(f"{where}: gecersiz type {ctype}")
        elif ctype == "convex":
            pts = c.get("points", [])
            if len(pts) < 4 or not all(is_vec3(q) for q in pts):
                errors.append(f"{where}: convex en az 4 adet [x,y,z] nokta olmali")
        else:
            if not is_vec3(c.get("pos")):
                errors.append(f"{where}: pos [x, y, z] olmali")
            if ctype == "box" and not is_vec3(c.get("size")):
                errors.append(f"{where}: box size [x, y, z] olmali")

# --- materials ---
for mid, m in materials.items():
    for key in ("density", "hp", "impact_threshold", "friction", "bounce", "flags"):
        if key not in m:
            errors.append(f"materials.{mid}: '{key}' eksik")
    bad = set(m.get("flags", [])) - VALID_FLAGS
    if bad:
        errors.append(f"materials.{mid}: bilinmeyen flag {bad}")
    if m.get("density", 1) <= 0:
        errors.append(f"materials.{mid}: density > 0 olmali")

# --- worlds ---
world_ids = [w.get("id") for w in worlds]
level_ids_expected: set[str] = set()
prev_req = -1
for w in worlds:
    wid = w.get("id")
    for mat in w.get("palette", {}):
        if mat not in materials:
            errors.append(f"worlds.{wid}.palette: '{mat}' materials.json'da yok")
    total = sum(w.get("palette", {}).values())
    if abs(total - 1.0) > 0.01:
        warnings.append(f"worlds.{wid}.palette toplam {total:.2f} (1.0 onerilir)")
    req = w.get("unlock_stars_required", 0)
    if req < prev_req:
        errors.append(f"worlds.{wid}: unlock_stars_required bir onceki dunyadan kucuk")
    prev_req = req
    max_prev_stars = (w.get("index", 1) - 1) * 30
    if req > max_prev_stars:
        errors.append(f"worlds.{wid}: {req} yildiz gerekiyor ama onceki dunyalarda en fazla {max_prev_stars} var")
    for i in range(1, w.get("level_count", 10) + 1):
        level_ids_expected.add(f"w{w.get('index', 0):02d}_l{i:02d}")

# --- balls ---
ball_ids = set()
for b in balls_doc.get("balls", []):
    bid = b.get("id")
    ball_ids.add(bid)
    u = b.get("unlock", {})
    if u.get("type") not in VALID_UNLOCK:
        errors.append(f"balls.{bid}: gecersiz unlock.type {u.get('type')}")
    if u.get("type") == "level_cleared" and u.get("level_id") not in level_ids_expected:
        errors.append(f"balls.{bid}: unlock.level_id '{u.get('level_id')}' gecerli bir bolum degil")
    for mat in b.get("damage_mult", {}):
        if mat not in materials:
            errors.append(f"balls.{bid}.damage_mult: '{mat}' materials.json'da yok")
    if b.get("gift_on_unlock", 0) != -1 and b.get("price_gold", 0) <= 0:
        errors.append(f"balls.{bid}: sinirli top icin price_gold > 0 olmali")
if "heavy" not in ball_ids:
    errors.append("balls: 'heavy' (baslangic topu) yok")

# --- economy ---
stars = economy.get("rewards", {}).get("stars", {})
if not (stars.get("1", 0) < stars.get("2", 0) < stars.get("3", 0)):
    errors.append("economy.rewards.stars: 1 < 2 < 3 olmali")
jackpot = economy.get("rewards", {}).get("core_jackpot_gold")
if not is_num(jackpot) or jackpot < 0:
    errors.append("economy.rewards.core_jackpot_gold 0 veya pozitif sayi olmali (K-018)")
eco_sim = economy.get("sim", {})
if not isinstance(eco_sim.get("core_jackpot_levels_per_world"), int) or eco_sim.get("core_jackpot_levels_per_world", -1) < 0:
    errors.append("economy.sim.core_jackpot_levels_per_world 0 veya pozitif tam sayi olmali")
if not is_num(eco_sim.get("avg_core_jackpot_rate")) or not 0 <= eco_sim["avg_core_jackpot_rate"] <= 1:
    errors.append("economy.sim.avg_core_jackpot_rate 0-1 araliginda olmali")

# --- difficulty ---
for name, pts in difficulty.get("curves", {}).items():
    xs = [p[0] for p in pts]
    if xs != sorted(xs):
        errors.append(f"difficulty.curves.{name}: x degerleri artan sirada olmali")

# --- levels ---
seen_levels = set()
for lf in sorted((ROOT / "levels").rglob("*.json")):
    rel = lf.relative_to(ROOT)
    try:
        lv = json.loads(lf.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"{rel}: JSON hatasi satir {e.lineno}: {e.msg}")
        continue
    lid = lv.get("id")
    seen_levels.add(lid)
    if lf.stem != lid:
        errors.append(f"{rel}: dosya adi id ile ayni olmali ({lid})")
    if lv.get("world") not in world_ids:
        errors.append(f"{rel}: world '{lv.get('world')}' worlds.json'da yok")
    objective = lv.get("objective", {})
    if objective.get("type") not in VALID_OBJECTIVES:
        errors.append(f"{rel}: gecersiz objective.type")
    if "target" in objective and (not is_num(objective["target"]) or not 0 < objective["target"] <= 1):
        errors.append(f"{rel}: objective.target 0 < x <= 1 olmali (clear_percent orani)")
    if lv.get("role") not in VALID_ROLES:
        errors.append(f"{rel}: gecersiz role '{lv.get('role')}'")
    if not 1 <= lv.get("shots", 0) <= 10:
        errors.append(f"{rel}: shots 1-10 araliginda olmali")
    plat = lv.get("platform", {})
    for key in ("width", "depth"):
        if not is_num(plat.get(key)) or plat.get(key) <= 0:
            errors.append(f"{rel}: platform.{key} pozitif sayi olmali (tam 3D: width=x, depth=z)")
    for st in lv.get("structures", []):
        for key in ("x", "z"):
            if key in st and not is_num(st[key]):
                errors.append(f"{rel}: structure '{st.get('template')}' {key} sayi olmali")
    core_size = shapes.get(obj_def.get("core_shape"), {}).get("size", [0, 0, 0])
    for c in lv.get("cores", []):
        if not all(is_num(c.get(k)) for k in ("x", "y", "z")):
            errors.append(f"{rel}: cores ogesi x, y, z icermeli")
        elif is_num(plat.get("width")) and is_num(plat.get("depth")) and is_vec3(core_size):
            if (abs(c["x"]) + core_size[0] / 2 > plat["width"] / 2 + 1e-6
                    or abs(c["z"]) + core_size[2] / 2 > plat["depth"] / 2 + 1e-6):
                errors.append(f"{rel}: kure ({c['x']}, {c['z']}) platformun disinda doguyor")
    block_ids = set()
    for blk in lv.get("blocks", []):
        if blk.get("shape") not in shapes:
            errors.append(f"{rel}: blok {blk.get('id')} shape '{blk.get('shape')}' yok")
        if blk.get("mat") not in materials:
            errors.append(f"{rel}: blok {blk.get('id')} mat '{blk.get('mat')}' yok")
        if not all(is_num(blk.get(k)) for k in ("x", "y", "z")):
            errors.append(f"{rel}: blok {blk.get('id')} x, y, z sayi olmali")
        if not is_vec3(blk.get("rot", [0, 0, 0])):
            errors.append(f"{rel}: blok {blk.get('id')} rot [rx, ry, rz] (derece) olmali")
        if blk.get("id") in block_ids:
            errors.append(f"{rel}: tekrar eden blok id {blk.get('id')}")
        # Kenar payi (docs/03 4. kural 5): yalnizca donmemis bloklar icin basit eksen hizali kontrol
        shp = shapes.get(blk.get("shape"), {})
        if (blk.get("rot", [0, 0, 0]) == [0, 0, 0] and is_vec3(shp.get("size"))
                and all(is_num(blk.get(k)) for k in ("x", "z")) and is_num(plat.get("width")) and is_num(plat.get("depth"))):
            inset = phys.get("spawn_edge_inset", 0)
            if (abs(blk["x"]) + shp["size"][0] / 2 > plat["width"] / 2 - inset + 1e-6
                    or abs(blk["z"]) + shp["size"][2] / 2 > plat["depth"] / 2 - inset + 1e-6):
                errors.append(f"{rel}: blok {blk.get('id')} platform kenarina {inset} birimden yakin")
        block_ids.add(blk.get("id"))
    for k in lv.get("keystones", []):
        if lv.get("baked") and k not in block_ids:
            errors.append(f"{rel}: keystone '{k}' blok listesinde yok")
    if lv.get("baked"):
        if not lv.get("blocks"):
            errors.append(f"{rel}: baked=true ama blocks bos")
        # cores yalnizca drop_core / drop_all_cores icin zorunlu; clear_percent'te opsiyonel jackpot kuresi (K-018)
        if objective.get("type") in CORE_OBJECTIVES and not lv.get("cores"):
            errors.append(f"{rel}: {objective.get('type')} hedefi ama cores bos")
        if not lv.get("keystones"):
            warnings.append(f"{rel}: keystone isaretlenmemis")
    for b in lv.get("free_balls", {}):
        if b not in ball_ids:
            errors.append(f"{rel}: free_balls '{b}' gecersiz top")

start_level = rules.get("dev", {}).get("start_level_id")
if start_level not in seen_levels:
    errors.append(f"rules.dev.start_level_id '{start_level}' icin bolum dosyasi yok")

missing = len(level_ids_expected - seen_levels)
if missing:
    warnings.append(f"{missing} bolum dosyasi henuz yok (normal: bolumler Faz 3/9'da uretilecek)")

for w in warnings:
    print(f"UYARI: {w}")
for e in errors:
    print(f"HATA:  {e}")
if errors:
    print(f"\n{len(errors)} hata bulundu.")
    sys.exit(1)
print(f"\nOK - game_data gecerli ({len(materials)} malzeme, {len(shapes)} sekil, {len(ball_ids)} top, {len(worlds)} dunya, {len(seen_levels)} bolum dosyasi).")
