extends GutTest
## LevelExpander + TemplateRegistry + TowerTemplate (Faz 3 Step 1), using tests/helpers/probe_template.gd.

const PROBE := preload("res://tests/helpers/probe_template.gd")


func before_all() -> void:
	TemplateRegistry.register("probe", PROBE)


func after_all() -> void:
	TemplateRegistry.unregister("probe")


func _level(structures: Array, extra: Dictionary = {}) -> Dictionary:
	var lv := {"id": "t", "world": "akdeniz", "index": 1, "difficulty": 50, "structures": structures,
			"blocks": [], "keystones": [], "cores": []}
	lv.merge(extra, true)
	return lv


func test_baked_or_plain_level_unchanged() -> void:
	var baked := _level([{"template": "probe"}], {"baked": true})
	assert_eq(LevelExpander.expand(baked), baked)
	var plain := _level([])
	assert_eq(LevelExpander.expand(plain), plain)


func test_expand_ids_keystones_cores() -> void:
	var out := LevelExpander.expand(_level([{"template": "probe", "seed": 1}, {"template": "probe", "x": 3, "seed": 2}]))
	assert_eq(out["blocks"].size(), 6)
	assert_eq(out["blocks"][0]["id"], "s1_b01")
	assert_eq(out["blocks"][3]["id"], "s2_b01")
	assert_eq(out["keystones"], ["s1_b01", "s2_b01"])
	assert_eq(out["cores"].size(), 2)


func test_offset_and_rotation() -> void:
	var out := LevelExpander.expand(_level([{"template": "probe", "x": 2, "z": -1, "ry": 90}]))
	var b: Dictionary = out["blocks"][0]  # local (1, 0, 0), turned 90° about +Y -> (0, 0, -1)
	assert_almost_eq(float(b["x"]), 2.0, 0.0001)
	assert_almost_eq(float(b["z"]), -2.0, 0.0001)
	assert_almost_eq(float(b["rot"][1]), 90.0, 0.0001)
	var c: Dictionary = out["cores"][0]
	assert_almost_eq(float(c["y"]), 2.0, 0.0001)


func test_roles_become_palette_materials() -> void:
	var out := LevelExpander.expand(_level([{"template": "probe"}]))
	var palette: Dictionary = GameConfig.world("akdeniz")["palette"]
	for b: Dictionary in out["blocks"]:
		assert_true(b.has("mat"))
	assert_true(palette.has(out["blocks"][0]["mat"]), "rol -> palet malzemesi")
	assert_true(str(out["blocks"][1]["mat"]).begins_with("crystal"), "kristal rolü -> kristal")
	assert_eq(out["blocks"][2]["mat"], "wood", "açık malzeme korunur")


func test_same_seed_same_tower_other_seed_differs() -> void:
	var a := LevelExpander.expand(_level([{"template": "probe", "seed": 7}]))
	var b := LevelExpander.expand(_level([{"template": "probe", "seed": 7}]))
	var c := LevelExpander.expand(_level([{"template": "probe", "seed": 8}]))
	assert_eq(a["blocks"], b["blocks"])
	assert_ne(a["blocks"][1]["x"], c["blocks"][1]["x"])


func test_structure_params_override_difficulty() -> void:
	var from_curve := LevelExpander.expand(_level([{"template": "probe"}]))
	assert_eq(float(from_curve["blocks"][2]["z"]), float(DifficultyCalc.params(50)["block_count"]))
	var overridden := LevelExpander.expand(_level([{"template": "probe", "params": {"block_count": 3}}]))
	assert_eq(float(overridden["blocks"][2]["z"]), 3.0)


func test_missing_template_is_skipped_with_warning() -> void:
	var out := LevelExpander.expand(_level([{"template": "yok_boyle_sablon"}]))
	assert_eq(out["blocks"].size(), 0)
	assert_eq(out["_expand_warnings"].size(), 1)


func test_difficulty_from_rhythm_when_missing() -> void:
	var lv := _level([])
	lv.erase("difficulty")
	lv["index"] = 3
	assert_eq(LevelExpander.difficulty_of(lv), 10.0)
