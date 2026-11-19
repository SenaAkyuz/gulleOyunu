extends GutTest
## Faz 3 Step 6: MaterialPicker (docs/03 §6.3, K-022) and core_protection (docs/03 §4 rule 6a).

const Kit = preload("res://tests/helpers/template_kit.gd")
const TEMPLATES := ["stack_pyramid", "twin_pillars", "arch_shrine", "staircase", "domino_row", "truss_bridge"]


func _level(template: String, d: float, seed: int, id: String, index: int, params: Dictionary = {}) -> Dictionary:
	var lv := {"id": id, "world": "akdeniz", "index": index, "difficulty": d,
			"structures": [{"template": template, "seed": seed, "params": params}],
			"blocks": [], "keystones": [], "cores": []}
	var out := LevelExpander.expand(lv)
	out["platform"] = LayoutCheck.platform_for(out["blocks"])
	return out


func _shatters(mat: String) -> bool:
	return (GameConfig.material(mat).get("flags", []) as Array).has("shatter")


func _heavy_share(lv: Dictionary) -> float:
	var solids := 0
	var heavy := 0
	for b: Dictionary in lv["blocks"]:
		if _shatters(b["mat"]) or b["shape"] == "ring_hanger":
			continue
		solids += 1
		if float(GameConfig.material(b["mat"])["density"]) > 1.5:
			heavy += 1
	return float(heavy) / maxf(1.0, solids)


func test_every_material_is_in_the_palette() -> void:
	var palette: Dictionary = GameConfig.world("akdeniz")["palette"]
	for t: String in TEMPLATES:
		for b: Dictionary in Kit.level(t, 30.0, 1)["blocks"]:
			assert_true(palette.has(b["mat"]), "%s %s: %s paletin dışında" % [t, b["id"], b["mat"]])


func test_heavier_with_difficulty() -> void:
	for t: String in ["staircase", "stack_pyramid"]:
		var low := _heavy_share(Kit.level(t, 10.0, 1))
		var high := _heavy_share(Kit.level(t, 45.0, 1))
		assert_gt(high, low, "%s: zorluk artınca ağır malzeme payı artmalı (%.2f -> %.2f)" % [t, low, high])


func test_heavy_at_the_bottom() -> void:
	var lv := Kit.level("stack_pyramid", 25.0, 1)
	var hy := 0.0
	var hn := 0
	var ly := 0.0
	var ln := 0
	for b: Dictionary in lv["blocks"]:
		if _shatters(b["mat"]):
			continue
		if float(GameConfig.material(b["mat"])["density"]) > 1.5:
			hy += float(b["y"])
			hn += 1
		else:
			ly += float(b["y"])
			ln += 1
	assert_true(hn > 0 and ln > 0, "hem ağır hem hafif blok olmalı")
	assert_lt(hy / hn, ly / ln, "ağır bloklar altta, hafifler üstte")


func test_keystones_stand_out() -> void:
	for t: String in TEMPLATES:
		for d: float in [5.0, 25.0, 45.0]:
			var lv := Kit.level(t, d, 2)
			var common := MaterialPicker.most_common(lv["blocks"])
			for b: Dictionary in lv["blocks"]:
				if lv["keystones"].has(b["id"]):
					assert_ne(b["mat"], common, "%s d=%d: keystone en yaygın malzemeden (%s) farklı olmalı" % [t, d, common])


func test_domino_stays_light_and_keystone_does_not_shatter() -> void:
	var lv := Kit.level("domino_row", 45.0, 1)
	for b: Dictionary in lv["blocks"]:
		if b["shape"] == "pillar_3":
			assert_false(_shatters(b["mat"]), "domino kristal olmamalı (devrilmeli)")


func test_fire_intro_level_is_wood_heavy() -> void:
	# balls.json: fire.tutorial_level_id = w01_l08 -> at least strong_material_share wood.
	var share := float(GameConfig.difficulty()["intro_ball"]["strong_material_share"])
	var strong := MaterialPicker.strong_materials("fire", GameConfig.world("akdeniz")["palette"])
	assert_true(strong.has("wood"))
	var lv := _level("twin_pillars", 25.0, 1, "w01_l08", 8)
	assert_eq(LevelExpander.material_context(lv)["intro_ball"], "fire")
	var solids := 0
	var wood := 0
	for b: Dictionary in lv["blocks"]:
		if _shatters(b["mat"]):
			continue
		solids += 1
		if strong.has(b["mat"]):
			wood += 1
	assert_gte(float(wood) / solids, share, "alev tanıtım bölümü: %d/%d güçlü malzeme" % [wood, solids])
	var bad := Kit.problems(lv)
	assert_eq(bad.size(), 0, "; ".join(bad))


func test_breather_has_more_crystals() -> void:
	var min_share := float(GameConfig.difficulty()["role_overrides"]["breather"]["crystal_ratio_min"])
	var lv := _level("stack_pyramid", 20.0, 1, "w01_l04", 4)  # rhythm: level 4 = breather
	assert_gte(MaterialPicker.crystal_share(lv["blocks"]), min_share)


func test_core_protection_levels() -> void:
	for prot in [0, 1, 2]:
		for t: String in ["stack_pyramid", "staircase", "truss_bridge"]:
			var lv := Kit.level(t, 25.0, 1, {"core_protection": prot})
			var cradles := 0
			var lids := 0
			for b: Dictionary in lv["blocks"]:
				cradles += 1 if b["shape"] == TowerTemplate.CRADLE else 0
				lids += 1 if b["shape"] == TowerTemplate.LID and float(b["y"]) > 0.0 and b.get("role") == TowerTemplate.ROLE_LIGHT else 0
			assert_eq(cradles, 1 if prot >= 1 else 0, "%s koruma %d: yuva" % [t, prot])
			assert_eq((lv["cores"] as Array).size(), 1)
			var bad := Kit.problems(lv)
			assert_eq(bad.size(), 0, "%s koruma %d: %s" % [t, prot, "; ".join(bad)])
			var r: Dictionary = await SupportCheck.physics_drift(lv, self)
			assert_true(r["ok"], "%s koruma %d: en çok kayan %s %.4f m" % [t, prot, r["worst"], r["max_drift"]])


func test_protection_follows_difficulty() -> void:
	# core_protection curve: 0 at d=1 -> 1 at d=50 (rounded): a high-difficulty pyramid gets a cradle.
	var easy := Kit.level("stack_pyramid", 5.0, 1)
	var hard := Kit.level("stack_pyramid", 60.0, 1)
	var count := func(lv: Dictionary) -> int:
		return (lv["blocks"] as Array).filter(func(b: Dictionary) -> bool: return b["shape"] == TowerTemplate.CRADLE).size()
	assert_eq(count.call(easy), 0)
	assert_eq(count.call(hard), 1)


func test_mirror_pairs_share_material() -> void:
	# A stone load on one end of a chord and wood on the other tipped the truss (found in Step 6).
	for t: String in ["truss_bridge", "twin_pillars", "arch_shrine"]:
		for d: float in [10.0, 40.0, 70.0]:
			var lv := Kit.level(t, d, 1)
			var by_key := {}
			for b: Dictionary in lv["blocks"]:
				if lv["keystones"].has(b["id"]) or is_zero_approx(float(b["x"])):
					continue
				var key := "%s|%s|%.2f|%.2f|%.2f" % [b["shape"], b.get("role", ""), float(b["y"]), absf(float(b["x"])), float(b["z"])]
				if by_key.has(key):
					assert_eq(b["mat"], by_key[key], "%s d=%d: ayna çifti %s farklı malzeme" % [t, d, key])
				else:
					by_key[key] = b["mat"]
