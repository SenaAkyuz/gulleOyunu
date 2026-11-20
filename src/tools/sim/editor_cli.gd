extends SceneTree
## Background worker for the level editor dock (Step 10). The editor runs no physics and no
## autoloads, so the dock starts this headless process and reads the JSON it writes:
##   godot --headless --fixed-fps 60 --path . -s src/tools/sim/editor_cli.gd -- --mode M --out FILE ...
## Modes:
##   expand    --level ID                       level file / generator result, expanded
##   generate  --level ID [--seed N] [--template T]   LevelGenerator.generate (all checks)
##   sim       --file LEVEL.json [--samples N]  LevelSim.run on an expanded level
## Output: {ok, mode, level (expanded), report, sim, error}. Never writes game_data.
## (Classes are loaded with load(): -s scripts compile before the autoloads exist.)


func _initialize() -> void:
	await process_frame
	var args := _args()
	var out := {"ok": false, "mode": str(args.get("mode", "")), "error": ""}
	var gen: Script = load("res://src/gameplay/level/level_generator.gd")
	var exp_s: Script = load("res://src/gameplay/level/level_expander.gd")
	var sim: Script = load("res://src/tools/sim/level_sim.gd")
	var cfg: Node = root.get_node("GameConfig")
	match out["mode"]:
		"expand":
			var id := str(args.get("level", ""))
			if cfg.level_ids().has(id):
				out["level"] = exp_s.expand(cfg.level(id))
				out["ok"] = true
				out["source"] = "dosya"
			else:
				var res: Dictionary = await gen.resolve(id, root)
				out["ok"] = res["ok"]
				out["level"] = res["level"]
				out["report"] = res["report"]
				out["source"] = res["source"]
		"generate":
			var wi: Vector2i = gen.parse_id(str(args.get("level", "")))
			var world: Dictionary = gen.world_by_index(wi.x)
			var opts := {"quiet": true}
			if args.has("seed"):
				opts["base_seed"] = int(args["seed"])
			if args.has("template"):
				opts["template"] = str(args["template"])
			var res: Dictionary = await gen.generate(str(world.get("id", "")), wi.y, root, opts)
			out["ok"] = res["ok"]
			out["level"] = res["expanded"]
			out["report"] = res["report"]
		"sim":
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("file", ""))))
			if parsed is Dictionary:
				var opts := {}
				if args.has("samples"):
					opts["samples"] = int(args["samples"])
					opts["greedy_samples"] = int(args["samples"])
				out["sim"] = await sim.run(parsed, root, opts)
				out["ok"] = true
			else:
				out["error"] = "bölüm dosyası okunamadı"
		_:
			out["error"] = "bilinmeyen mod"
	# Write next to the target, then rename: the dock never reads a half-written file.
	var target := _abs(str(args.get("out", "user://editor/out.json")))
	var tmp := target + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(tmp, target)
	quit()


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path


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
