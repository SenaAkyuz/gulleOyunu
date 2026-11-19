extends GutTest
## Faz 3 Step 4: arch_shrine + staircase (docs/03 §4), the same checks as Step 3 over
## d = 1/15/25 and each template's own range, 3 seeds each; plus arch-specific cases
## (cradle core stays put, looking through the arch is not "blocked"), staircase lean direction,
## block counts end to end (no double expansion) and L03 opening full.

const Kit = preload("res://tests/helpers/template_kit.gd")
const LEVEL_SCENE := preload("res://src/gameplay/level/level.tscn")
const SEEDS := [1, 2, 3]
const RANGES := {
	"arch_shrine": [1.0, 15.0, 25.0, 5.0, 30.0, 60.0],
	"staircase": [1.0, 15.0, 25.0, 10.0, 30.0, 50.0],
}


func after_each() -> void:
	LevelLoader.dev_level_data = {}


func test_static_checks_over_range() -> void:
	for t: String in RANGES:
		for d: float in RANGES[t]:
			for s: int in SEEDS:
				var bad := Kit.problems(Kit.level(t, d, s))
				assert_eq(bad.size(), 0, "%s d=%d seed=%d: %s" % [t, d, s, "; ".join(bad)])


func test_physics_does_not_drift() -> void:
	for t: String in RANGES:
		for d: float in RANGES[t]:
			var r: Dictionary = await SupportCheck.physics_drift(Kit.level(t, d, 1), self)
			assert_true(r["ok"], "%s d=%d: en çok kayan %s %.4f m" % [t, d, r["worst"], r["max_drift"]])


# --- arch_shrine ---

func test_arch_core_in_cradle_inside_and_top() -> void:
	for mode: String in ["inside", "top"]:
		var lv := Kit.level("arch_shrine", 20.0, 1, {"core": mode})
		assert_eq((lv["cores"] as Array).size(), 1, mode)
		var has_hanger := false
		for b: Dictionary in lv["blocks"]:
			has_hanger = has_hanger or b["shape"] == "ring_hanger"
		assert_true(has_hanger, mode + ": yuva olmalı")
		var r: Dictionary = await SupportCheck.physics_drift(lv, self)
		assert_lt(float(r["drifts"]["core1"]), float(GameConfig.rule("physics.max_settle_drift")),
				"%s: küre yuvada dengede durmalı" % mode)


func test_arch_keystone_is_a_foot() -> void:
	var lv := Kit.level("arch_shrine", 30.0, 2)
	for k: String in lv["keystones"]:
		for b: Dictionary in lv["blocks"]:
			if b["id"] == k:
				assert_eq(b["shape"], "cube")
				assert_eq(float(b["y"]), 0.0)


func test_looking_through_the_arch_is_not_blocked() -> void:
	# A crystal cube right behind an arch's opening: the camera sees it through the arch.
	var lv := {"id": "t", "platform": {"width": 6, "depth": 5}, "cores": [], "keystones": ["k"], "blocks": [
		{"id": "a", "shape": "arch", "mat": "stone", "x": 0, "y": 0, "z": 0.6, "rot": [0, 0, 0]},
		{"id": "k", "shape": "cube", "mat": "crystal_amber", "x": 0, "y": 0, "z": -0.8, "rot": [0, 0, 0]}]}
	var r := KeystoneCheck.check(lv)
	assert_gt(float(r["keystones"]["k"]["visible_ratio"]), float(GameConfig.rule("level_checks.keystone_min_visible_ratio")),
			"kemerin açıklığı görüşü kapatmamalı")
	assert_true(r["keystones"]["k"]["reachable"], "kemerin içinden vurulabilmeli")


# --- staircase ---

func test_staircase_lean_direction_from_seed() -> void:
	var sides := {}
	for s in range(1, 9):
		var lv := Kit.level("staircase", 30.0, s)
		for b: Dictionary in lv["blocks"]:
			if lv["keystones"].has(b["id"]):
				sides[signf(float(b["x"]))] = true
	assert_eq(sides.size(), 2, "seed'e göre iki yöne de yaslanmalı")


func test_staircase_leans() -> void:
	# Low symmetry -> the wall's top cube sticks out past the bottom row.
	var lv := Kit.level("staircase", 50.0, 1, {"symmetry": 0.0})
	var key_x := 0.0
	var top_x := 0.0
	var top_y := -1.0
	for b: Dictionary in lv["blocks"]:
		if lv["keystones"].has(b["id"]):
			key_x = float(b["x"])
		if float(b["y"]) > top_y:
			top_y = float(b["y"])
			top_x = float(b["x"])
	assert_gt(absf(top_x), absf(key_x), "duvar dışa yaslanmalı")


# --- counts end to end ---

func test_block_counts_match_everywhere() -> void:
	for t: String in ["stack_pyramid", "twin_pillars", "arch_shrine", "staircase"]:
		var lv := Kit.level(t, 30.0, 1)
		var p := DifficultyCalc.params(30.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var expected: Dictionary = TemplateRegistry.create(t).generate(p, rng)
		assert_eq((lv["blocks"] as Array).size(), (expected["blocks"] as Array).size(), t + ": genişletme")
		assert_eq(LevelExpander.expand(lv), lv, t + ": ikinci genişletme bir şey değiştirmemeli")
		var counts: Dictionary = await _scene_counts(lv)
		assert_eq(counts["blocks"], (expected["blocks"] as Array).size(), t + ": sahnedeki blok")
		assert_eq(counts["cores"], (expected["cores"] as Array).size(), t + ": sahnedeki küre")


func test_level_03_opens_full() -> void:
	var lv := LevelExpander.expand(GameConfig.level("w01_l03"))
	assert_eq((lv["_expand_warnings"] as PackedStringArray).size(), 0)
	assert_gt((lv["blocks"] as Array).size(), 0)
	assert_eq((lv["cores"] as Array).size(), 1, "drop_core bölümünde küre olmalı")
	var bad := Kit.problems(lv)
	assert_eq(bad.size(), 0, "; ".join(bad))
	LevelLoader.dev_level_id = "w01_l03"
	var counts: Dictionary = await _scene_counts({})
	LevelLoader.dev_level_id = ""
	assert_eq(counts["blocks"], (lv["blocks"] as Array).size())
	assert_eq(counts["cores"], 1)


## Loads level.tscn (with `lv` as in-memory level, or the dev level file when lv is empty)
## and returns how many blocks / cores the tower really spawned.
func _scene_counts(lv: Dictionary) -> Dictionary:
	LevelLoader.dev_level_data = lv
	var scene: Node = LEVEL_SCENE.instantiate()
	add_child(scene)
	await wait_physics_frames(2)
	var tower: TowerBuilder = scene.get_node("Tower")
	var out := {"blocks": tower.blocks.size(), "cores": tower.cores.size()}
	scene.queue_free()
	await wait_process_frames(1)
	LevelLoader.dev_level_data = {}
	return out
