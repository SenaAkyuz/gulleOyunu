extends GutTest
## LevelGenerator (docs/03 §8, Faz 3 Step 7): plan, determinism, every World 1 level passing all
## checks, no back-to-back template repeats, files never touched, the give-up path.

const FLOATING := preload("res://tests/helpers/floating_template.gd")
const WORLD := "akdeniz"


func before_all() -> void:
	LevelGenerator.clear_cache()


func test_plan_world_1() -> void:
	var plan := LevelGenerator.plan_world(WORLD)
	var t: Array = plan["templates"]
	assert_eq((plan["errors"] as PackedStringArray).size(), 0, "; ".join(plan["errors"]))
	assert_eq(t.size(), 10)
	assert_eq(t[0], LevelGenerator.HANDMADE, "L01 elle (baked) dosya")
	assert_eq(t[2], "arch_shrine", "L03 dosyasının şablonu korunur")
	for i in range(1, t.size()):
		assert_ne(t[i], t[i - 1], "L%02d ve L%02d aynı şablon: %s" % [i, i + 1, t[i]])
	gut.p("Dünya 1 planı: %s" % [t])


func test_plan_respects_ranges_and_world() -> void:
	var world := GameConfig.world(WORLD)
	var plan := LevelGenerator.plan_world(WORLD)
	var ranges: Dictionary = GameConfig.difficulty()["templates"]
	for k in range(1, 11):
		var tpl: String = plan["templates"][k - 1]
		if tpl == LevelGenerator.HANDMADE or GameConfig.level_ids().has(LevelGenerator.level_id(1, k)):
			continue
		var d := DifficultyCalc.level_difficulty(1, k)
		assert_true((world["allowed_templates"] as Array).has(tpl), "%s dünyada izinli değil" % tpl)
		assert_between(d, float(ranges[tpl][0]), float(ranges[tpl][1]), "L%02d %s zorluk aralığı" % [k, tpl])


func test_same_seed_same_tower() -> void:
	var a: Dictionary = await LevelGenerator.generate(WORLD, 5, self)
	var b: Dictionary = await LevelGenerator.generate(WORLD, 5, self)
	assert_true(a["ok"])
	assert_eq(a["level"], b["level"])
	assert_eq(a["expanded"]["blocks"], b["expanded"]["blocks"])
	var c: Dictionary = await LevelGenerator.generate(WORLD, 5, self, {"base_seed": 4242})
	assert_ne(a["expanded"]["blocks"], c["expanded"]["blocks"], "başka seed başka kule")


func test_every_world_1_level_passes() -> void:
	var plan := LevelGenerator.plan_world(WORLD)
	var lines := PackedStringArray()
	for k in range(1, 11):
		var id := LevelGenerator.level_id(1, k)
		var res: Dictionary = await LevelGenerator.resolve(id, self)
		assert_true(res["ok"], "%s üretilemedi: %s" % [id, res.get("report", {})])
		if not res["ok"]:
			continue
		var lv: Dictionary = res["level"]
		var bad := LevelChecks.flatten(LevelChecks.static_problems(lv))
		assert_eq(bad.size(), 0, "%s: %s" % [id, "; ".join(bad)])
		var phys: Dictionary = await SupportCheck.physics_drift(lv, self)
		assert_true(phys["ok"], "%s: %s %.4f m kaydı" % [id, phys["worst"], phys["max_drift"]])
		# Every structure has its own keystone.
		var n_struct := (lv.get("structures", []) as Array).size()
		if not bool(lv.get("baked", false)):
			for s in range(1, n_struct + 1):
				var has_key := false
				for k_id: String in lv["keystones"]:
					has_key = has_key or k_id.begins_with("s%d_" % s)
				assert_true(has_key, "%s yapı %d keystone'suz" % [id, s])
		if k == 10:
			assert_gte(n_struct, 2, "boss en az 2 yapı (role_overrides.boss)")
		lines.append("%s: %s · %d blok" % [id, LevelGenerator.describe(res), (lv["blocks"] as Array).size()])
		assert_eq(plan["templates"][k - 1], LevelGenerator.HANDMADE if bool(lv.get("baked", false)) else str(lv["structures"][0]["template"]))
	gut.p("\n" + "\n".join(lines))


func test_files_are_never_touched() -> void:
	var before := FileAccess.get_file_as_string("res://game_data/levels/w01_akdeniz/w01_l01.json")
	var r1: Dictionary = await LevelGenerator.resolve("w01_l01", self)
	var r3: Dictionary = await LevelGenerator.resolve("w01_l03", self)
	assert_eq(r1["source"], LevelGenerator.SOURCE_BAKED)
	assert_eq(r3["source"], LevelGenerator.SOURCE_FILE)
	assert_eq(FileAccess.get_file_as_string("res://game_data/levels/w01_akdeniz/w01_l01.json"), before)
	var r4: Dictionary = await LevelGenerator.resolve("w01_l04", self)
	assert_eq(r4["source"], LevelGenerator.SOURCE_CANDIDATE, "L04 elle yapılacak: yalnızca aday")
	var r2: Dictionary = await LevelGenerator.resolve("w01_l02", self)
	assert_eq(r2["source"], LevelGenerator.SOURCE_GENERATED)


func test_gives_up_without_relaxing() -> void:
	TemplateRegistry.register("floating", FLOATING)
	var res: Dictionary = await LevelGenerator.generate(WORLD, 2, self, {"template": "floating"})
	TemplateRegistry.unregister("floating")
	assert_push_error_count(1, "vazgeçince tek hata mesajı")
	assert_false(res["ok"])
	var max_attempts := int(GameConfig.rule("generator.max_attempts"))
	assert_eq(int(res["report"]["attempts"]), max_attempts)
	var fails: Dictionary = res["report"]["fail_counts"]
	var total := 0
	for k: String in fails:
		total += int(fails[k])
	assert_eq(total, max_attempts, "her deneme bir kontrole takılmalı: %s" % fails)
	assert_gt(int(fails[LevelChecks.SUPPORT]), 0, "havadaki küp denge kontrolüne takılmalı: %s" % fails)


func test_static_checks_really_report() -> void:
	# Guard for the PackedStringArray copy bug: a broken level must produce problems in every group.
	var lv := {"id": "bad", "platform": {"width": 4, "depth": 4}, "cores": [], "keystones": ["gone"], "blocks": [
		{"id": "a", "shape": "cube", "mat": "stone", "x": 0, "y": 1, "z": 0, "rot": [0, 0, 0]}]}
	var p := LevelChecks.static_problems(lv)
	assert_gt((p[LevelChecks.LAYOUT] as PackedStringArray).size(), 0, "yerleşim: keystone yok, kristal yok")
	assert_gt((p[LevelChecks.SUPPORT] as PackedStringArray).size(), 0, "denge: havadaki küp")
	assert_gt((p[LevelChecks.KEYSTONE] as PackedStringArray).size(), 0, "keystone listede yok")
	assert_eq(LevelChecks.first_failure(p), LevelChecks.LAYOUT)


func test_world_1_uses_variety() -> void:
	var t: Array = LevelGenerator.plan_world(WORLD)["templates"]
	var used := {}
	for x in t:
		used[x] = true
	# Every template that can meet some slot's ground cap + budget limit must appear (variety);
	# templates that fit no slot (domino_row: all dominoes stand on the platform) are reported.
	var world := GameConfig.world(WORLD)
	for name: String in world["allowed_templates"]:
		var fits_somewhere := false
		for k in range(1, 11):
			var d := DifficultyCalc.level_difficulty(1, k)
			if LevelGenerator.candidates(world, d).has(name) and LevelGenerator.feasible_variant(world, name, d, DifficultyCalc.role_for(k)) >= 0:
				fits_somewhere = true
		if fits_somewhere:
			assert_true(used.has(name), "Dünya 1 planında %s hiç yok: %s" % [name, t])
		else:
			gut.p("%s hiçbir bölümün yere değen hacim / bütçe sınırına uymuyor" % name)
