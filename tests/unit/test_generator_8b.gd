extends GutTest
## Step 8b (Sena 2026-11-20): keystone_clear_min and within-shots sim in the generator loop,
## chained multi-structure layout.

const WORLD := "akdeniz"
const Kit = preload("res://tests/helpers/template_kit.gd")



func before_all() -> void:
	LevelGenerator.use_disk_cache = false  # tests always generate for real
	LevelGenerator.clear_cache()

func test_accepted_levels_meet_the_sim_checks() -> void:
	var within := float(GameConfig.difficulty()["sim_targets"]["min_solve_rate_within_shots"])
	for k in range(1, 11):
		var id := LevelGenerator.level_id(1, k)
		if GameConfig.level_ids().has(id):
			continue
		var res: Dictionary = await LevelGenerator.resolve(id, self)
		if not res["ok"]:
			assert_eq(Kit.failure_report_problem(res), "", id + " başarısızlık raporu eksik")
			assert_push_error(id, "üretilemeyen bölüm için generator hata mesajı")
			gut.p("%s üretilemedi: %s" % [id, "; ".join(res["report"]["last_problems"])])
			continue
		var r: Dictionary = res["report"]
		assert_gte(float(r["keystone_share"]), LevelGenerator.keystone_share_required(DifficultyCalc.role_for(k)), id + ": keystone atışı hedefi tutmalı")
		assert_gte(float(r["within_shots"]), within, id + ": gülleyle çözüm oranı")


func test_chain_puts_second_structure_on_keystone_side() -> void:
	# Find a twin_pillars seed whose keystone is on each side; the second structure must follow it.
	var world := GameConfig.world(WORLD)
	for want: float in [-1.0, 1.0]:
		var found := false
		for seed in range(1, 40):
			var level := {"id": "c", "world": WORLD, "index": 6, "difficulty": 15.0, "blocks": [], "keystones": [], "cores": [],
					"structures": [{"template": "twin_pillars", "seed": seed, "params": {"block_count": 7}},
						{"template": "staircase", "seed": 5, "params": {"block_count": 6}}]}
			if LevelGenerator._keystone_side(level, 0) != want:
				continue
			LevelGenerator._layout(level)
			var x1 := float(level["structures"][0]["x"])
			var x2 := float(level["structures"][1]["x"])
			assert_eq(signf(x2 - x1), want, "ikinci yapı keystone tarafında (seed %d)" % seed)
			found = true
			break
		assert_true(found, "keystone tarafı %d olan seed bulunamadı" % want)
	assert_true(world["allowed_templates"].has("twin_pillars"))


func test_keystone_share_helper() -> void:
	var clears := {"a": [0.9, 0.5, 0.85], "b": [0.2, 0.3, 0.1]}
	assert_almost_eq(LevelGenerator._best_keystone_share(clears, 0.8), 2.0 / 3.0, 0.001)
	assert_eq(LevelGenerator._best_keystone_share({"a": [0.1]}, 0.8), 0.0)
