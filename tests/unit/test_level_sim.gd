extends GutTest
## LevelSim (docs/03 §8.1). The full World 1 run is the CLI (src/tools/sim/sim_cli.gd, --fixed-fps);
## here: the L01 keystone shot (K-021: one shot clears ~86 %) and the target comparison logic.


func test_level_01_keystone_shot_solves() -> void:
	var lv := LevelExpander.expand(GameConfig.level("w01_l01"))
	var r: Dictionary = await LevelSim.run(lv, self, {"samples": 0, "greedy_samples": 0})
	assert_true(r["keystones"]["b02"]["solved"], "L01 keystone atışı bölümü çözmeli (K-021)")
	assert_gte(float(r["keystones"]["b02"]["collapse"]), float(GameConfig.difficulty()["sim_targets"]["min_collapse_ratio"]))
	assert_gt(LevelSim.visible_targets(lv).size(), 0)


func test_compare_against_targets() -> void:
	var t: Dictionary = GameConfig.difficulty()["sim_targets"]
	var lo := float(t["one_shot_solve_rate"]["intro"][0])
	var report := {"role": "intro", "one_shot_solve_rate": lo - 0.01, "within_shots_rate": 1.0,
			"keystones": {"k": {"solved": true, "collapse": 1.0}}}
	var v := LevelSim.compare(report)
	assert_false(v["one_shot_solve_rate"]["ok"], "aralığın altı uyarı")
	assert_true(v["within_shots_rate"]["ok"])
	assert_true(v["keystone_collapse"]["ok"])
	report["one_shot_solve_rate"] = lo + 0.01
	assert_true(LevelSim.compare(report)["one_shot_solve_rate"]["ok"])
