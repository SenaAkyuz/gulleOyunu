extends GutTest
## DifficultyCalc (src/core/difficulty_calc.gd): docs/03 §6 formula and curve interpolation.


func test_world1_levels_match_existing_files() -> void:
	# w01_l01.json says difficulty 2 (intro), w01_l03.json says 10 (build_up).
	assert_eq(DifficultyCalc.level_difficulty(1, 1), 2.0)
	assert_eq(DifficultyCalc.level_difficulty(1, 3), 10.0)
	assert_eq(DifficultyCalc.role_for(1), "intro")
	assert_eq(DifficultyCalc.role_for(10), "boss")


func test_world_step_and_clamp() -> void:
	var d := GameConfig.difficulty()
	var step := float(d["world_base"]["step_per_world"])
	assert_eq(DifficultyCalc.level_difficulty(2, 1) - DifficultyCalc.level_difficulty(1, 1), step)
	assert_eq(DifficultyCalc.level_difficulty(99, 10), DifficultyCalc.MAX_DIFFICULTY)


func test_global_multiplier() -> void:
	var d := GameConfig.difficulty().duplicate(true)
	d["global_multiplier"] = 0.5
	assert_eq(DifficultyCalc.level_difficulty(1, 3, d), 5.0)


func test_interp() -> void:
	var pts := [[1, 6], [50, 28], [100, 60]]
	assert_eq(DifficultyCalc.interp(pts, 1), 6.0)
	assert_eq(DifficultyCalc.interp(pts, 50), 28.0)
	assert_almost_eq(DifficultyCalc.interp(pts, 75), 44.0, 0.001)
	assert_eq(DifficultyCalc.interp(pts, -5), 6.0, "alt uca kırpılır")
	assert_eq(DifficultyCalc.interp(pts, 500), 60.0, "üst uca kırpılır")


func test_params_rounds_count_curves() -> void:
	var p := DifficultyCalc.params(25.0)
	assert_typeof(p["block_count"], TYPE_INT)
	assert_typeof(p["heavy_ratio"], TYPE_FLOAT)
	assert_true(p.has("depth_layers") and p.has("symmetry"))
	assert_eq(DifficultyCalc.params(1.0)["block_count"], 6)
