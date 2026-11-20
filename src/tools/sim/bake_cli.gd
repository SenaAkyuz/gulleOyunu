extends SceneTree
## Step 11: bakes a chosen level into game_data (docs/03 §2.1 "baked", §9). Every block is written
## out explicitly, so later template / generator changes never alter a shipped level.
##   godot --headless --path . -s src/tools/sim/bake_cli.gd -- --level w01_l05 --from _candidates/w01_l05/cand_1.json
##   godot --headless --path . -s src/tools/sim/bake_cli.gd -- --level w01_l03 --from-file
##   ... --draft   (hand-made slot filled with a candidate until it is designed by hand)
## --from: a candidate JSON (candidates_cli output, its "level" is used); --from-file: the level's
## own file (template calls expanded). Writes game_data/levels/wNN_<world>/<id>.json.
## (Classes are loaded with load(): -s scripts compile before the autoloads exist.)

const KEEP_OUT: PackedStringArray = ["structures", "_expanded", "_expand_warnings", "generated", "rank", "score"]


func _initialize() -> void:
	await process_frame
	var args := _args()
	var gen: Script = load("res://src/gameplay/level/level_generator.gd")
	var exp_s: Script = load("res://src/gameplay/level/level_expander.gd")
	var cfg: Node = root.get_node("GameConfig")
	var id := str(args.get("level", ""))
	var wi: Vector2i = gen.parse_id(id)
	var world: Dictionary = gen.world_by_index(wi.x)
	var level: Dictionary = {}
	var source := ""
	if args.has("from"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args["from"])))
		if parsed is Dictionary and (parsed as Dictionary).has("level"):
			level = parsed["level"]
			source = "aday %s (şablon %s, seed %d)" % [str(args["from"]).get_file(), parsed.get("template", "?"), int(parsed.get("seed", 0))]
	elif args.has("from-file"):
		level = exp_s.expand(cfg.level(id))
		source = "dosyanın şablonu"
	if level.is_empty() or world.is_empty():
		push_error("bake_cli: bölüm bulunamadı (%s)" % id)
		quit(1)
		return
	var out := level.duplicate(true)
	for k in KEEP_OUT:
		out.erase(k)
	out["id"] = id
	out["world"] = str(world["id"])
	out["index"] = wi.y
	out["baked"] = true
	if args.has("draft"):
		out["draft"] = true
	out["_doc"] = "Faz 3 Adim 11'de pisirildi: %s.%s" % [source,
			" TASLAK: elle tasarlanacak bolum (docs/03 9); simdilik en iyi aday." if args.has("draft") else ""]
	var path := "res://game_data/levels/w%02d_%s/%s.json" % [wi.x, world["id"], id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", false))
	f.close()
	print("BAKE %s <- %s (%d blok)" % [path, source, (out.get("blocks", []) as Array).size()])
	quit()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--"):
			if i + 1 < a.size() and not a[i + 1].begins_with("--"):
				out[a[i].substr(2)] = a[i + 1]
				i += 2
			else:
				out[a[i].substr(2)] = true
				i += 1
		else:
			i += 1
	return out
