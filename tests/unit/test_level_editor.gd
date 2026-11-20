extends GutTest
## Step 10 level editor: what can be verified headless — the preview round trip (JSON -> nodes ->
## JSON, gizmo edits come back) and the background worker the dock starts (editor_cli: expand,
## generate, sim). The dock UI itself is checked by hand in the editor.

const TIMEOUT_MS := 180000


func _data() -> Dictionary:
	var shapes := {}
	for id: String in ["cube", "half", "pillar_2", "pillar_3", "plank_s", "plank_l", "beam", "arch", "wedge", "ring_hanger", "core_sphere"]:
		shapes[id] = GameConfig.shape(id)
	return {"shapes": shapes, "rules": GameConfig.rules()}


func test_preview_round_trip() -> void:
	var lv := LevelExpander.expand(GameConfig.level("w01_l01"))
	var root := LevelPreview.build(lv, _data())
	add_child_autofree(root)
	var back := LevelPreview.read(root)
	assert_eq(back["keystones"], lv["keystones"])
	assert_eq((back["blocks"] as Array).size(), (lv["blocks"] as Array).size())
	for i in (lv["blocks"] as Array).size():
		var a: Dictionary = lv["blocks"][i]
		var b: Dictionary = back["blocks"][i]
		assert_eq(b["id"], a["id"])
		assert_eq(b["shape"], a["shape"])
		assert_eq(b["mat"], a["mat"])
		assert_almost_eq(Vector3(b["x"], b["y"], b["z"]), Vector3(a["x"], a["y"], a["z"]), Vector3.ONE * 0.001)
	assert_eq((back["cores"] as Array).size(), 1)
	assert_eq(back["platform"], lv["platform"], "başlık bilgileri korunur")


func test_gizmo_edit_comes_back() -> void:
	var root := LevelPreview.build(LevelExpander.expand(GameConfig.level("w01_l01")), _data())
	add_child_autofree(root)
	var plank := root.get_node("b03") as Node3D
	plank.position += Vector3(0.5, 0, -0.25)
	plank.rotation_degrees.y = 30.0
	var b: Dictionary = LevelPreview.read(root)["blocks"][2]
	assert_eq(b["id"], "b03")
	assert_almost_eq(float(b["x"]), 0.5, 0.001)
	assert_almost_eq(float(b["z"]), -0.25, 0.001)
	assert_almost_eq(float(b["rot"][1]), 30.0, 0.001)


func test_template_level_preview_reads_back_as_baked_blocks() -> void:
	var lv := LevelExpander.expand(GameConfig.level("w01_l03"))
	var root := LevelPreview.build(lv, _data())
	add_child_autofree(root)
	var back := LevelPreview.read(root)
	assert_eq((back["blocks"] as Array).size(), (lv["blocks"] as Array).size())
	back["baked"] = true
	assert_eq(LevelChecks.flatten(LevelChecks.static_problems(back)).size(), 0, "önizlemeden okunan bölüm kontrolleri geçer")


func _worker(args: Array, name: String) -> Dictionary:
	var out := ProjectSettings.globalize_path("user://editor/gut_%s.json" % name)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var full := ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "-s", "src/tools/sim/editor_cli.gd", "--"]
	full.append_array(args)
	full.append_array(["--out", out])
	var t0 := Time.get_ticks_msec()
	var pid := OS.create_process(OS.get_executable_path(), full)
	assert_gt(pid, 0, "arka plan süreci başlamalı")
	# Real time (the test runs with --fixed-fps, so game-time waits would be too short).
	while not FileAccess.file_exists(out) and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		OS.delay_msec(200)
		await get_tree().process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out)) if FileAccess.file_exists(out) else null
	return parsed if parsed is Dictionary else {}


func test_background_worker_expand_generate_sim() -> void:
	var opened := await _worker(["--mode", "expand", "--level", "w01_l03"], "expand")
	assert_true(bool(opened.get("ok", false)), "aç: L03 dosyası")
	assert_eq((opened["level"]["blocks"] as Array).size(), (LevelExpander.expand(GameConfig.level("w01_l03"))["blocks"] as Array).size())
	var gen := await _worker(["--mode", "generate", "--level", "w01_l02", "--seed", "1000"], "generate")
	assert_true(bool(gen.get("ok", false)), "üret: L02")
	var file := ProjectSettings.globalize_path("user://editor/gut_sim_in.json")
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string(JSON.stringify(gen["level"]))
	f.close()
	var sim := await _worker(["--mode", "sim", "--file", file, "--samples", "10"], "sim")
	assert_true(bool(sim.get("ok", false)), "simüle et")
	assert_true((sim.get("sim", {}) as Dictionary).has("verdict"))
