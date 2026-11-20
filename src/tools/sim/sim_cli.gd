extends SceneTree
## Command line for LevelSim (docs/03 §8.1). Run headless with a fixed step so the simulation runs
## as fast as the CPU allows and is deterministic:
##   godot --headless --fixed-fps 60 --path . -s src/tools/sim/sim_cli.gd -- --world akdeniz
##   godot --headless --fixed-fps 60 --path . -s src/tools/sim/sim_cli.gd -- --level w01_l02 --samples 50
## Options: --level ID | --world ID, --samples N (default difficulty.sim_targets.samples),
##          --greedy N (multi-shot runs, default = samples), --batch K (parallel copies, default 20).
## Writes one JSON per level + summary.md to res://_sim_reports/ (git-ignored) and prints a table.
## Only measures and compares with difficulty.sim_targets; never changes a level.
## (Classes are loaded with load(): -s scripts compile before the autoloads exist.)

const OUT_DIR := "res://_sim_reports/"


func _initialize() -> void:
	await process_frame
	var gen: Script = load("res://src/gameplay/level/level_generator.gd")
	var sim: Script = load("res://src/tools/sim/level_sim.gd")
	var cfg: Node = root.get_node("GameConfig")
	var args := _args()
	var ids := PackedStringArray()
	if args.has("level"):
		ids.append(str(args["level"]))
	else:
		var world: Dictionary = cfg.world(str(args.get("world", "akdeniz")))
		for k in range(1, int(world.get("level_count", 0)) + 1):
			ids.append(gen.level_id(int(world["index"]), k))
	var opts := {"batch": int(args.get("batch", 20))}
	if args.has("samples"):
		opts["samples"] = int(args["samples"])
	if args.has("greedy"):
		opts["greedy_samples"] = int(args["greedy"])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var gd := ProjectSettings.globalize_path(OUT_DIR).path_join(".gdignore")
	if not FileAccess.file_exists(gd):
		FileAccess.open(gd, FileAccess.WRITE).close()
	var lines := PackedStringArray(["| Bölüm | Kaynak | Rol | Yere değen (tavan) | Tek atış | Hedef | Keystone (başarı / çöküş) | Jackpot | Gülleyle çözüm | Süre (sn) |",
			"|---|---|---|---|---|---|---|---|---|---|"])
	var total := 0.0
	for id in ids:
		var res: Dictionary = await gen.resolve(id, root)
		if not res["ok"]:
			lines.append("| %s | üretilemedi | | | | | | | | |" % id)
			continue
		var report: Dictionary = await sim.run(res["level"], root, opts)
		report["source"] = res["source"]
		var lc: Script = load("res://src/gameplay/level/level_checks.gd")
		var lv: Dictionary = res["level"]
		report["ground"] = lc.ground_contact_ratio(lv)
		report["ground_cap"] = lc.ground_cap(float(lv.get("difficulty", 1.0)), str(report["role"]))
		total += float(report["seconds"])
		var f := FileAccess.open(OUT_DIR + id + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
		lines.append(_row(id, res, report))
		print(lines[-1])
	lines.append("")
	lines.append("Toplam süre: %.1f sn (%d bölüm)" % [total, ids.size()])
	var md := FileAccess.open(OUT_DIR + "summary.md", FileAccess.WRITE)
	md.store_string("\n".join(lines))
	md.close()
	print("\n".join(lines))
	quit()


func _row(id: String, res: Dictionary, r: Dictionary) -> String:
	var v: Dictionary = r["verdict"]
	var one: Dictionary = v.get("one_shot_solve_rate", {})
	var keys := PackedStringArray()
	for k: String in r["keystones"]:
		var kr: Dictionary = r["keystones"][k]
		keys.append("%s %s / %%%d" % [k, "✔" if kr["solved"] else "✘", roundi(float(kr["collapse"]) * 100.0)])
	var src := str(res["source"])
	src = "aday" if src.contains("aday") else src.split(" ")[0]
	return "| %s | %s | %s | %%%d (%%%d) | %%%d %s | %s | %s %s | %%%d | %%%d %s | %.1f |" % [
		id, src, r["role"], roundi(float(r.get("ground", 0.0)) * 100.0), roundi(float(r.get("ground_cap", 0.0)) * 100.0),
		roundi(float(r["one_shot_solve_rate"]) * 100.0), _mark(one),
		_range(one.get("target", [])),
		", ".join(keys), _mark(v.get("keystone_collapse", {})),
		roundi(float(r["jackpot_rate"]) * 100.0),
		roundi(float(r["within_shots_rate"]) * 100.0), _mark(v.get("within_shots_rate", {})),
		float(r["seconds"])]


func _mark(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	return "✔" if bool(m.get("ok", false)) else "⚠"


func _range(t: Array) -> String:
	return "%%%d–%%%d" % [roundi(float(t[0]) * 100.0), roundi(float(t[1]) * 100.0)] if t.size() == 2 else ""


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
