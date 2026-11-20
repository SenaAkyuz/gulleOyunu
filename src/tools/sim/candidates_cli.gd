extends SceneTree
## Step 9: candidate pipeline from the command line (docs/03 §8).
##   godot --fixed-fps 60 --path . -s src/tools/sim/candidates_cli.gd -- --world akdeniz
##   godot --headless --fixed-fps 60 --path . -s src/tools/sim/candidates_cli.gd -- --level w01_l05 --count 5
## Options: --level ID | --world ID, --count N (default 5), --samples N (default difficulty.sim_targets.samples).
## Without --headless it also takes a screenshot of every candidate (level scene, default camera).
## Writes res://_candidates/<level>/cand_<rank>.json (+ .png) and res://_candidates/summary.md
## (git-ignored). Never writes to game_data: hand-made slots and file levels only get suggestions.
## (Classes are loaded with load(): -s scripts compile before the autoloads exist.)

const OUT_DIR := "res://_candidates/"
const LEVEL_SCENE := "res://src/gameplay/level/level.tscn"
const SHOT_FRAMES := 30


func _initialize() -> void:
	await process_frame
	var started := Time.get_ticks_msec()
	var gen: Script = load("res://src/gameplay/level/level_generator.gd")
	var pipe: Script = load("res://src/tools/sim/candidates.gd")
	var lc: Script = load("res://src/gameplay/level/level_checks.gd")
	var cfg: Node = root.get_node("GameConfig")
	var args := _args()
	var count := int(args.get("count", 5))
	var samples := int(args.get("samples", cfg.difficulty().get("sim_targets", {}).get("samples", 200)))
	var shots := DisplayServer.get_name() != "headless"
	var targets := []  # [world_id, index]
	if args.has("level"):
		var wi: Vector2i = gen.parse_id(str(args["level"]))
		targets.append([str(gen.world_by_index(wi.x)["id"]), wi.y])
	else:
		var world: Dictionary = cfg.world(str(args.get("world", "akdeniz")))
		for k in range(1, int(world.get("level_count", 0)) + 1):
			targets.append([str(world["id"]), k])
	_ensure_dir(OUT_DIR)
	var md := PackedStringArray()
	for tgt in targets:
		var world_id: String = tgt[0]
		var index: int = tgt[1]
		var wi := int(cfg.world(world_id)["index"])
		var id: String = gen.level_id(wi, index)
		var t0 := Time.get_ticks_msec()
		var cands: Array = await pipe.run_level(world_id, index, root, count, samples)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		var dir := OUT_DIR + id + "/"
		_ensure_dir(dir)
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
		var note := ""
		if cfg.level_ids().has(id):
			note = " (dosyası var — yalnızca öneri, dosya değişmez)"
		elif gen.is_handmade_slot(index):
			note = " (elle tasarlanacak — yalnızca öneri)"
		md.append("\n### %s · %s · zorluk %.0f%s · %.0f sn\n" % [id, root.get_node("GameConfig").difficulty()["rhythm"][index - 1]["role"], load("res://src/core/difficulty_calc.gd").level_difficulty(wi, index), note, secs])
		md.append("| Sıra | Şablon | Seed | Durum | Tek atış (hedef) | Keystone merkez (çöküş) | Gülleyle çözüm | Yere değen | Bütçe | Görüntü |")
		md.append("|---|---|---|---|---|---|---|---|---|---|")
		for c in cands:
			var name := "cand_%d" % int(c["rank"])
			var f := FileAccess.open(dir + name + ".json", FileAccess.WRITE)
			f.store_string(JSON.stringify(c, "\t"))
			f.close()
			var img := ""
			if shots and c["ok"]:
				img = await _screenshot(c["level"], dir + name + ".png")
			md.append(_row(c, lc, img))
		print("\n".join(md.slice(md.size() - cands.size() - 3)))
	md.insert(0, "# Aday hattı — %s\n\n%d aday / bölüm, %d örnek. Toplam süre: %.1f dk." % [
		args.get("level", args.get("world", "akdeniz")), count, samples, (Time.get_ticks_msec() - started) / 60000.0])
	var out := FileAccess.open(OUT_DIR + "summary.md", FileAccess.WRITE)
	out.store_string("\n".join(md))
	out.close()
	print(md[0])
	quit()


func _row(c: Dictionary, lc: Script, img: String) -> String:
	if not c["ok"]:
		var r: Dictionary = c.get("report", {})
		return "| %d | %s | %d | ✘ geçmedi: %s | | | | | | |" % [c["rank"], c["template"], c["seed"], "; ".join(PackedStringArray(r.get("last_problems", [])))]
	var s: Dictionary = c["sim"]
	var v: Dictionary = s["verdict"]
	var one: Dictionary = v.get("one_shot_solve_rate", {})
	var key_best := 0.0
	var key_ok := false
	for k: String in s["keystones"]:
		key_best = maxf(key_best, float(s["keystones"][k]["collapse"]))
		key_ok = key_ok or bool(s["keystones"][k]["solved"])
	var rep: Dictionary = c["report"]
	return "| %d | %s | %d | ✔ %d/4 hedef | %%%d %s (%s) | %s %%%d | %%%d %s | %%%d | %%%d | %s |" % [
		c["rank"], "+".join(PackedStringArray(rep.get("templates", [c["template"]]))), c["seed"], int(c["score"][0]),
		roundi(float(s["one_shot_solve_rate"]) * 100.0), "✔" if bool(one.get("ok", false)) else "⚠", _range(one.get("target", [])),
		"✔" if key_ok else "✘", roundi(key_best * 100.0),
		roundi(float(s["within_shots_rate"]) * 100.0), "✔" if bool(v["within_shots_rate"]["ok"]) else "⚠",
		roundi(lc.ground_contact_ratio(c["level"]) * 100.0), roundi(float(rep.get("fill", 0.0)) * 100.0), img]


func _screenshot(level: Dictionary, path: String) -> String:
	var ll: Script = load("res://src/gameplay/level/level_loader.gd")
	ll.dev_level_data = level
	change_scene_to_file(LEVEL_SCENE)
	for i in SHOT_FRAMES:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	ll.dev_level_data = {}
	return path.get_file()


func _range(t: Array) -> String:
	return "%%%d–%%%d" % [roundi(float(t[0]) * 100.0), roundi(float(t[1]) * 100.0)] if t.size() == 2 else ""


func _ensure_dir(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var gd := ProjectSettings.globalize_path(OUT_DIR).path_join(".gdignore")
	if not FileAccess.file_exists(gd):
		FileAccess.open(gd, FileAccess.WRITE).close()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			out[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	return out
