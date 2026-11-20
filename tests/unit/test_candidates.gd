extends GutTest
## Step 9 candidate pipeline (src/tools/sim/candidates.gd): ranking, template order, and a small
## real run that never touches game_data.


func before_all() -> void:
	LevelGenerator.use_disk_cache = false


func _sim(one: float, lo: float, hi: float, within_ok: bool, key_ok: bool) -> Dictionary:
	return {"verdict": {
		"one_shot_solve_rate": {"value": one, "target": [lo, hi], "ok": one >= lo and one <= hi},
		"within_shots_rate": {"ok": within_ok}, "keystone_collapse": {"ok": key_ok}, "keystone_success": {"ok": key_ok}}}


func test_score_ranks_targets_then_distance() -> void:
	var on_target := CandidatePipeline.score(_sim(0.2, 0.1, 0.3, true, true))
	var too_easy := CandidatePipeline.score(_sim(0.5, 0.1, 0.3, true, true))
	var way_too_easy := CandidatePipeline.score(_sim(0.9, 0.1, 0.3, true, true))
	var failed := CandidatePipeline.score({})
	assert_true(CandidatePipeline.better(on_target, too_easy), "hedefteki önce")
	assert_true(CandidatePipeline.better(too_easy, way_too_easy), "hedefe yakın olan önce")
	assert_true(CandidatePipeline.better(way_too_easy, failed), "geçemeyen en sonda")
	assert_eq(on_target[0], 2, "yalnız sim hedefleri sayılır (keystone generator kontrolü)")
	# A candidate whose centre keystone shot misses but whose rates are on target still ranks first.
	assert_true(CandidatePipeline.better(CandidatePipeline.score(_sim(0.2, 0.1, 0.3, true, false)), too_easy))


func test_templates_for_slot() -> void:
	var t := CandidatePipeline.templates_for("akdeniz", 5)
	assert_gt(t.size(), 0)
	var plan: Array = LevelGenerator.plan_world("akdeniz")["templates"]
	assert_eq(t[0], plan[4], "plandaki şablon önce")
	assert_false(t.has(plan[3]) and t[0] != plan[3] and t.find(plan[3]) > 0, "komşu şablon yedek listede olmaz")


func test_small_run_never_touches_files() -> void:
	var before := FileAccess.get_file_as_string("res://game_data/levels/w01_akdeniz/w01_l01.json")
	var cands: Array[Dictionary] = await CandidatePipeline.run_level("akdeniz", 1, self, 2, 6)
	assert_eq(cands.size(), 2)
	assert_eq(cands[0]["rank"], 1)
	assert_ne(cands[0]["seed"], cands[1]["seed"], "her aday ayrı seed")
	assert_eq(FileAccess.get_file_as_string("res://game_data/levels/w01_akdeniz/w01_l01.json"), before, "elle bölüm dosyası değişmez")
	for c in cands:
		if c["ok"]:
			assert_true((c["sim"] as Dictionary).has("verdict"))
