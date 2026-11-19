class_name LevelExpander
extends RefCounted
## Expands a level's "structures" (template calls, docs/03 §2.1) into concrete blocks/cores/keystones.
## - baked levels, or levels without structures, are returned unchanged.
## - Hand-placed "blocks" / "cores" / "keystones" of the file are kept; template output is appended.
## - Each structure: params = DifficultyCalc.params(level difficulty) overridden by structure.params;
##   rng seeded with structure.seed; result moved to (x, 0, z) and turned by ry (degrees, about +Y).
## - Template block ids get the structure prefix "s<n>_" (s1_b01, ...); roles become materials
##   (MaterialPicker, world palette).
## - A template that is not written yet is skipped with a warning (returned in "_expand_warnings").

const ID_PREFIX := "s%d_"


static func expand(level: Dictionary) -> Dictionary:
	var structures: Array = level.get("structures", [])
	if bool(level.get("baked", false)) or structures.is_empty():
		return level
	var out := level.duplicate(true)
	var blocks: Array = out.get("blocks", [])
	var keystones: Array = out.get("keystones", [])
	var cores: Array = out.get("cores", [])
	var warnings: PackedStringArray = []
	var world := GameConfig.world(str(level.get("world", "")))
	var base := DifficultyCalc.params(difficulty_of(level))

	var n := 0
	for st: Dictionary in structures:
		n += 1
		var tpl := TemplateRegistry.create(str(st.get("template", "")))
		if tpl == null:
			warnings.append("şablon henüz yok: %s" % st.get("template"))
			continue
		var p := base.duplicate()
		p.merge(st.get("params", {}), true)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(st.get("seed", 0))
		var res := tpl.generate(p, rng)
		var origin := Vector3(float(st.get("x", 0)), 0.0, float(st.get("z", 0)))
		var ry := float(st.get("ry", 0))
		var prefix := ID_PREFIX % n
		for b: Dictionary in res["blocks"]:
			var nb := _place(b, origin, ry)
			nb["id"] = prefix + str(b["id"])
			if not nb.has("mat"):
				nb["mat"] = MaterialPicker.pick(str(nb.get("role", "")), world, p, rng)
			blocks.append(nb)
		for k: String in res["keystones"]:
			keystones.append(prefix + k)
		for c: Dictionary in res["cores"]:
			cores.append(_place(c, origin, ry))

	out["blocks"] = blocks
	out["keystones"] = keystones
	out["cores"] = cores
	out["_expand_warnings"] = warnings
	for w in warnings:
		push_warning("LevelExpander %s: %s" % [level.get("id", "?"), w])
	return out


## The level's difficulty: its "difficulty" field, else computed from world index + level index.
static func difficulty_of(level: Dictionary) -> float:
	if level.has("difficulty"):
		return float(level["difficulty"])
	var world := GameConfig.world(str(level.get("world", "")))
	return DifficultyCalc.level_difficulty(int(world.get("index", 1)), int(level.get("index", 1)))


## Copy of a local block/core dict moved into the level frame.
static func _place(d: Dictionary, origin: Vector3, ry_deg: float) -> Dictionary:
	var out := d.duplicate(true)
	var local := Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
	var p := local.rotated(Vector3.UP, deg_to_rad(ry_deg)) + origin
	out["x"] = p.x
	out["y"] = p.y
	out["z"] = p.z
	if d.has("rot"):
		var r: Array = d["rot"]
		out["rot"] = [float(r[0]), float(r[1]) + ry_deg, float(r[2])]
	return out
