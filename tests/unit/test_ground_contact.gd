extends GutTest
## ground_contact_max_ratio + budget_max_over (Sena 2026-11-20, after the Step 8 sim):
## the measure, the caps, the raised / half-feet variants and the generator enforcing both.

const Kit = preload("res://tests/helpers/template_kit.gd")
const WORLD := "akdeniz"


func _b(shape: String, x: float, y: float, mat: String = "stone") -> Dictionary:
	return {"id": "%s_%s_%s" % [shape, x, y], "shape": shape, "mat": mat, "x": x, "y": y, "z": 0, "rot": [0, 0, 0]}


func test_ratio_measure() -> void:
	var one := {"blocks": [_b("cube", 0, 0)], "cores": []}
	assert_almost_eq(LevelChecks.ground_contact_ratio(one), 1.0, 0.001)
	var stack := {"blocks": [_b("cube", 0, 0), _b("cube", 0, 1)], "cores": []}
	assert_almost_eq(LevelChecks.ground_contact_ratio(stack), 0.5, 0.001)
	# Step 8 measurement: L01 (passes the sim targets) = 27 %.
	var l01 := LevelExpander.expand(GameConfig.level("w01_l01"))
	assert_almost_eq(LevelChecks.ground_contact_ratio(l01), 0.27, 0.01)


func test_caps() -> void:
	var curve: Array = GameConfig.difficulty()["curves"]["ground_contact_max_ratio"]
	var easy := float(GameConfig.difficulty()["role_overrides"]["intro"]["ground_contact_max_ratio"])
	assert_almost_eq(LevelChecks.ground_cap(80.0, "intro"), easy, 0.001, "kolay rol tavanı eğriyi keser")
	assert_almost_eq(LevelChecks.ground_cap(80.0, "challenge"), DifficultyCalc.interp(curve, 80.0), 0.001, "challenge eğriyi izler")
	assert_gt(LevelChecks.ground_cap(80.0, "boss"), LevelChecks.ground_cap(80.0, "breather"))
	var over := float(GameConfig.rule("generator.budget_max_over"))
	assert_eq(LevelChecks.budget_max(8), floori(8 * (1.0 + over)))


func test_raised_variants_pass_everything() -> void:
	for t: String in ["stack_pyramid", "staircase"]:
		for d: float in [5.0, 15.0, 25.0]:
			var lv := Kit.level(t, d, 1, {"raised": true})
			var bad := Kit.problems(lv)
			assert_eq(bad.size(), 0, "%s yükseltilmiş d=%d: %s" % [t, d, "; ".join(bad)])
			assert_lte(LevelChecks.ground_contact_ratio(lv), 0.30, "%s yükseltilmiş d=%d yere değen hacim" % [t, d])
			var stilt_key := false
			for b: Dictionary in lv["blocks"]:
				if lv["keystones"].has(b["id"]) and b["shape"] == TowerTemplate.STILT and float(b["y"]) == 0.0:
					stilt_key = str(b["mat"]).begins_with("crystal")
			assert_true(stilt_key, "%s yükseltilmiş: ön ayaklardan biri kristal keystone" % t)
			var r: Dictionary = await SupportCheck.physics_drift(lv, self)
			assert_true(r["ok"], "%s yükseltilmiş d=%d: %s %.4f m" % [t, d, r["worst"], r["max_drift"]])


func test_arch_half_feet_variant() -> void:
	for d: float in [5.0, 15.0, 25.0]:
		var lv := Kit.level("arch_shrine", d, 1, {"side_towers": false, "feet": "half"})
		var bad := Kit.problems(lv)
		assert_eq(bad.size(), 0, "kemer yarım ayak d=%d: %s" % [d, "; ".join(bad)])
		assert_lte(LevelChecks.ground_contact_ratio(lv), 0.30)
		var r: Dictionary = await SupportCheck.physics_drift(lv, self)
		assert_true(r["ok"], "kemer yarım ayak d=%d: %s %.4f m" % [d, r["worst"], r["max_drift"]])


func test_generated_world_1_within_caps() -> void:
	LevelGenerator.clear_cache()
	var world := GameConfig.world(WORLD)
	for k in range(1, 11):
		var id := LevelGenerator.level_id(1, k)
		if GameConfig.level_ids().has(id):
			continue  # files are never changed (L01, L03): reported, not enforced
		var res: Dictionary = await LevelGenerator.resolve(id, self)
		assert_true(res["ok"], id)
		var d := DifficultyCalc.level_difficulty(1, k)
		var lv: Dictionary = res["level"]
		assert_lte(LevelChecks.ground_contact_ratio(lv), LevelChecks.ground_cap(d, DifficultyCalc.role_for(k)) + 1e-6, id + " yere değen hacim")
		assert_lte((lv["blocks"] as Array).size(), LevelChecks.budget_max(int(DifficultyCalc.params(d)["block_count"])), id + " bütçe üst sınırı")
	assert_false(LevelGenerator.plan_world(WORLD)["templates"].has("domino_row"), "domino hiçbir Dünya 1 bölümüne uymuyor")
	gut.p("Dünya 1: %s" % [LevelGenerator.plan_world(WORLD)["templates"]])
	assert_true(world["allowed_templates"].has("domino_row"))


func test_forced_domino_is_rejected() -> void:
	# L02 (budget 8, max 10, easy-role cap 0.30): a domino tower (12 blocks, 76 % on the ground)
	# must fail every attempt — never accepted by relaxing a rule.
	var res: Dictionary = await LevelGenerator.generate(WORLD, 2, self, {"template": "domino_row"})
	assert_push_error_count(1)
	assert_false(res["ok"])
	var f: Dictionary = res["report"]["fail_counts"]
	assert_eq(int(f[LevelChecks.BUDGET]) + int(f[LevelChecks.GROUND]) + int(f[LevelChecks.LAYOUT]) + int(f[LevelChecks.SUPPORT]) + int(f[LevelChecks.KEYSTONE]),
			int(GameConfig.rule("generator.max_attempts")), str(f))
	assert_gt(int(f[LevelChecks.BUDGET]) + int(f[LevelChecks.GROUND]), 0, str(f))
