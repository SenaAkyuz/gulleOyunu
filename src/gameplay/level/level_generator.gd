class_name LevelGenerator
extends RefCounted
## Level generator (docs/03 §8 pipeline): difficulty + world + role (+ seed) -> a checked level.
##
## plan_world(): one template per level of a world, deterministic from generator.base_seed:
##   - a level that has a JSON file keeps its own template (hand-made files are never touched);
##   - otherwise a template that is in worlds.allowed_templates, written (TemplateRegistry) and whose
##     difficulty range (difficulty.templates) contains the level's difficulty;
##   - never the same template as the previous level, nor as the next level when that one is a file;
##   - among those, the ones this world has used least so far (variety), the seed breaks ties.
## generate() (async: needs the scene tree for the physics check):
##   - structure_count from the difficulty curve (boss: role_overrides.boss.structure_count_min);
##     the block budget (curve block_count) is split between the structures; while the generated
##     blocks fill less than generator.budget_warn_below of the budget, another structure is added
##     next to them (up to generator.max_structures, inside the play area) — docs/03 §5;
##   - every attempt uses its own sub-seed; it must pass LevelChecks (layout, support, keystones of
##     every structure) and the pre-settle physics run. After generator.max_attempts failures it
##     gives up — rules are never relaxed — and reports how often each check failed.
## resolve(): what the game plays for a level id: the file if there is one, else the generator
## output (cached per session). Hand-made slots (difficulty.handmade_levels) without a file get a
## generator candidate, marked as such.

const SOURCE_BAKED := "elle (baked)"
const SOURCE_FILE := "dosya (şablon)"
const SOURCE_GENERATED := "generator"
const SOURCE_CANDIDATE := "generator adayı (elle yapılacak)"
## Template label of a level file that lists its blocks by hand.
const HANDMADE := "elle"
const ID_FORMAT := "w%02d_l%02d"
## Seed mixing primes (any distinct large primes; only determinism matters).
const SEED_WORLD := 10007
const SEED_LEVEL := 101
const SEED_ATTEMPT := 7919
const SEED_BASE := 1000003

static var _cache: Dictionary = {}


static func level_id(world_index: int, index: int) -> String:
	return ID_FORMAT % [world_index, index]


## Vector2i(world_index, level_index), or (-1, -1) when the id is not wNN_lMM.
static func parse_id(id: String) -> Vector2i:
	if id.length() == 7 and id[0] == "w" and id[3] == "_" and id[4] == "l" \
			and id.substr(1, 2).is_valid_int() and id.substr(5, 2).is_valid_int():
		return Vector2i(id.substr(1, 2).to_int(), id.substr(5, 2).to_int())
	return Vector2i(-1, -1)


static func world_by_index(world_index: int) -> Dictionary:
	for w: Dictionary in GameConfig.worlds():
		if int(w.get("index", 0)) == world_index:
			return w
	return {}


static func is_handmade_slot(index: int) -> bool:
	return (GameConfig.difficulty().get("handmade_levels", []) as Array).has(float(index)) \
			or (GameConfig.difficulty().get("handmade_levels", []) as Array).has(index)


static func clear_cache() -> void:
	_cache.clear()


## Template of a level file: its first structure's template, or HANDMADE for hand-placed blocks.
static func file_template(lv: Dictionary) -> String:
	var st: Array = lv.get("structures", [])
	if bool(lv.get("baked", false)) or st.is_empty():
		return HANDMADE
	return str((st[0] as Dictionary).get("template", ""))


## Templates allowed for this world at difficulty d (allowed, written, range contains d), sorted.
static func candidates(world: Dictionary, d: float) -> PackedStringArray:
	var ranges: Dictionary = GameConfig.difficulty().get("templates", {})
	var out := PackedStringArray()
	for t: String in world.get("allowed_templates", []):
		var r: Array = ranges.get(t, [])
		if r.size() == 2 and d >= float(r[0]) and d <= float(r[1]) and TemplateRegistry.has(t):
			out.append(t)
	out.sort()
	return out


static func seed_for(world_index: int, index: int, attempt: int, base_seed: int) -> int:
	return base_seed * SEED_BASE + world_index * SEED_WORLD + index * SEED_LEVEL + attempt * SEED_ATTEMPT


static func _base_seed(opts: Dictionary) -> int:
	return int(opts.get("base_seed", GameConfig.rule("generator.base_seed")))


## {templates: [String] (index 1 -> [0]), sources: [String], errors: [String]}
static func plan_world(world_id: String, opts: Dictionary = {}) -> Dictionary:
	var world := GameConfig.world(world_id)
	var wi := int(world.get("index", 0))
	var count := int(world.get("level_count", 0))
	var files := {}
	for k in range(1, count + 1):
		var id := level_id(wi, k)
		if GameConfig.level_ids().has(id):
			files[k] = file_template(GameConfig.level(id))
	var templates: Array[String] = []
	var sources: Array[String] = []
	var errors := PackedStringArray()
	for k in range(1, count + 1):
		if files.has(k):
			templates.append(str(files[k]))
			sources.append(SOURCE_BAKED if files[k] == HANDMADE else SOURCE_FILE)
			continue
		var d := DifficultyCalc.level_difficulty(wi, k)
		var pool := candidates(world, d)
		var avoid: Array[String] = []
		if k > 1:
			avoid.append(templates[k - 2])
		if files.has(k + 1):
			avoid.append(str(files[k + 1]))
		# Variety: among the allowed templates prefer the ones this world has used least so far.
		var allowed := PackedStringArray()
		var least := INF
		for t in pool:
			if not avoid.has(t):
				least = minf(least, templates.count(t))
		for t in pool:
			if not avoid.has(t) and templates.count(t) == least:
				allowed.append(t)
		if allowed.is_empty():
			errors.append("%s: şablon yok (zorluk %.0f, aday %s, kaçınılan %s)" % [level_id(wi, k), d, pool, avoid])
			templates.append("")
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_for(wi, k, 0, _base_seed(opts))
			templates.append(allowed[rng.randi_range(0, allowed.size() - 1)])
		sources.append(SOURCE_CANDIDATE if is_handmade_slot(k) else SOURCE_GENERATED)
	return {"templates": templates, "sources": sources, "errors": errors}


## Generates world_id level `index`. opts: base_seed, template (forces the first structure).
## {ok, level (structures + platform, not expanded), expanded, report}
## report: {templates, attempts, fail_counts {layout, support, keystone, physics}, budget, used,
##          fill, warnings, last_problems}
static func generate(world_id: String, index: int, node: Node, opts: Dictionary = {}) -> Dictionary:
	var world := GameConfig.world(world_id)
	var wi := int(world.get("index", 0))
	var d := DifficultyCalc.level_difficulty(wi, index)
	var role := DifficultyCalc.role_for(index)
	var params := DifficultyCalc.params(d)
	var overrides: Dictionary = (GameConfig.difficulty().get("role_overrides", {}) as Dictionary).get(role, {})
	var first := str(opts.get("template", ""))
	if first.is_empty():
		var plan := plan_world(world_id, opts)
		first = str((plan["templates"] as Array)[index - 1]) if index - 1 < (plan["templates"] as Array).size() else ""
	var pool := candidates(world, d)
	var fail_counts := {LevelChecks.LAYOUT: 0, LevelChecks.SUPPORT: 0, LevelChecks.KEYSTONE: 0, LevelChecks.PHYSICS: 0}
	var report := {"templates": [], "attempts": 0, "fail_counts": fail_counts, "budget": int(params["block_count"]),
			"used": 0, "fill": 0.0, "warnings": [], "last_problems": PackedStringArray()}
	if first.is_empty() or not TemplateRegistry.has(first):
		(report["warnings"] as Array).append("şablon seçilemedi: '%s'" % first)
		return {"ok": false, "level": {}, "expanded": {}, "report": report}

	var max_attempts := int(GameConfig.rule("generator.max_attempts"))
	for attempt in max_attempts:
		report["attempts"] = attempt + 1
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_for(wi, index, attempt, _base_seed(opts))
		var level := _build_level(world, wi, index, d, role, params, overrides, first, pool, rng)
		var expanded := LevelExpander.expand(level)
		var problems := LevelChecks.static_problems(expanded)
		var failed := LevelChecks.first_failure(problems)
		if failed.is_empty():
			var phys: Dictionary = await SupportCheck.physics_drift(expanded, node)
			if not phys["ok"]:
				failed = LevelChecks.PHYSICS
				problems[LevelChecks.PHYSICS] = PackedStringArray(["%s %.4f m kaydı" % [phys["worst"], phys["max_drift"]]])
		if not failed.is_empty():
			fail_counts[failed] = int(fail_counts[failed]) + 1
			report["last_problems"] = LevelChecks.flatten(problems)
			continue
		var used := (expanded["blocks"] as Array).size()
		report["used"] = used
		report["fill"] = float(used) / maxf(1.0, float(report["budget"]))
		var names: Array = []
		for st: Dictionary in level["structures"]:
			names.append(st["template"])
		report["templates"] = names
		if float(report["fill"]) < float(GameConfig.rule("generator.budget_warn_below")):
			(report["warnings"] as Array).append("bütçe %%%d dolu (%d / %d blok)" % [
					roundi(float(report["fill"]) * 100.0), used, int(report["budget"])])
		return {"ok": true, "level": level, "expanded": expanded, "report": report}
	push_error("LevelGenerator %s: %d denemede geçen kule yok; düşen kontroller %s; son sorunlar: %s" % [
			level_id(wi, index), max_attempts, fail_counts, "; ".join(report["last_problems"])])
	return {"ok": false, "level": {}, "expanded": {}, "report": report}


## What the game plays for `id`: {ok, level (expanded), source, report}.
static func resolve(id: String, node: Node) -> Dictionary:
	if GameConfig.level_ids().has(id):
		var lv := GameConfig.level(id)
		var src := SOURCE_BAKED if file_template(lv) == HANDMADE else SOURCE_FILE
		return {"ok": true, "level": LevelExpander.expand(lv), "source": src, "report": {}}
	if _cache.has(id):
		return _cache[id]
	var wi := parse_id(id)
	var world := world_by_index(wi.x)
	if world.is_empty() or wi.y < 1 or wi.y > int(world.get("level_count", 0)):
		return {"ok": false, "level": {}, "source": "", "report": {}}
	var res: Dictionary = await generate(str(world["id"]), wi.y, node)
	var out := {"ok": res["ok"], "level": res["expanded"], "report": res["report"],
			"source": SOURCE_CANDIDATE if is_handmade_slot(wi.y) else SOURCE_GENERATED}
	if res["ok"]:
		_cache[id] = out
	return out


## Short one-line summary for the dev panel / HUD.
static func describe(res: Dictionary) -> String:
	var r: Dictionary = res.get("report", {})
	if r.is_empty():
		return str(res.get("source", ""))
	var text := "%s · %s · deneme %d · bütçe %%%d" % [res.get("source", ""), "+".join(PackedStringArray(r.get("templates", []))),
			int(r.get("attempts", 0)), roundi(float(r.get("fill", 0.0)) * 100.0)]
	if not (r.get("warnings", []) as Array).is_empty():
		text += " · UYARI: " + "; ".join(PackedStringArray(r["warnings"]))
	return text


# --- Building one attempt ---

static func _build_level(world: Dictionary, wi: int, index: int, d: float, role: String, params: Dictionary,
		overrides: Dictionary, first: String, pool: PackedStringArray, rng: RandomNumberGenerator) -> Dictionary:
	var budget := int(params["block_count"])
	var count := maxi(1, maxi(int(params.get("structure_count", 1)), int(overrides.get("structure_count_min", 1))))
	count = mini(count, int(GameConfig.rule("generator.max_structures")))
	var min_count := count  # never fewer (boss: role_overrides.boss.structure_count_min)
	var structs: Array[Dictionary] = []
	for k in count:
		var t := first if k == 0 else _pick_other(pool, structs, first, rng)
		structs.append({"template": t, "seed": rng.randi(), "params": {"block_count": budget / count}})
	var level := {
		"id": level_id(wi, index), "world": str(world["id"]), "index": index,
		"name_tr": "Bölüm %d" % index, "difficulty": d, "role": role,
		"shots": int(params["shots"]) + int(overrides.get("shots_bonus", 0)),
		"objective": {"type": str(GameConfig.rule("objective_defaults.type"))},
		"aim_preview_dots": int(params["aim_preview_dots"]),
		"structures": structs, "blocks": [], "joints": [], "cores": [], "keystones": [],
		"intro_ball": null, "free_balls": {}, "baked": false,
		"generated": {"base_seed": int(GameConfig.rule("generator.base_seed"))},
	}
	# Fill the budget with extra structures while there is room (docs/03 §5).
	var warn := float(GameConfig.rule("generator.budget_warn_below"))
	while true:
		_layout(level)
		var used := (LevelExpander.expand(level)["blocks"] as Array).size()
		var fits := _fits(level)
		if not fits:
			# Drop only an extra structure; if the required ones do not fit, this attempt fails
			# the layout check and the next sub-seed tries narrower picks.
			if structs.size() > min_count:
				structs.pop_back()
				_layout(level)
			break
		if float(used) / maxf(1.0, budget) >= warn or structs.size() >= int(GameConfig.rule("generator.max_structures")):
			break
		structs.append({"template": _pick_other(pool, structs, first, rng), "seed": rng.randi(),
				"params": {"block_count": maxi(1, budget - used)}})
	var final_blocks: Array = LevelExpander.expand(level)["blocks"]
	level["platform"] = LayoutCheck.platform_for(final_blocks)
	level["platform"]["style"] = str(world.get("platform_style", ""))
	return level


## Another template from the pool (prefers one not used yet; may repeat when the pool is small).
static func _pick_other(pool: PackedStringArray, structs: Array[Dictionary], first: String, rng: RandomNumberGenerator) -> String:
	var unused := PackedStringArray()
	for t in pool:
		var used := t == first
		for st in structs:
			used = used or st["template"] == t
		if not used:
			unused.append(t)
	var from := unused if not unused.is_empty() else (pool if not pool.is_empty() else PackedStringArray([first]))
	return from[rng.randi_range(0, from.size() - 1)]


## Places the structures side by side along x (generator.structure_gap), centred on the origin.
static func _layout(level: Dictionary) -> void:
	var gap := float(GameConfig.rule("generator.structure_gap"))
	var boxes: Array[AABB] = []
	var total := 0.0
	for st: Dictionary in level["structures"]:
		var single := level.duplicate(true)
		var s := st.duplicate(true)
		s["x"] = 0.0
		s["z"] = 0.0
		s["ry"] = 0.0
		single["structures"] = [s]
		var box := _bounds(LevelExpander.expand(single))
		boxes.append(box)
		total += box.size.x
	total += gap * (boxes.size() - 1)
	var left := -total / 2.0
	for i in boxes.size():
		var st: Dictionary = level["structures"][i]
		st["x"] = snappedf(left - boxes[i].position.x, 0.001)
		st["z"] = 0.0
		st["ry"] = 0.0
		left += boxes[i].size.x + gap


## True when every block of the level is inside the playable area (x).
static func _fits(level: Dictionary) -> bool:
	var guide: Dictionary = GameConfig.rule("dev.play_area_guide")
	var box := _bounds(LevelExpander.expand(level))
	return box.position.x >= float(guide["min"][0]) and box.end.x <= float(guide["max"][0])


static func _bounds(lv: Dictionary) -> AABB:
	var box := AABB()
	var first := true
	for b: Dictionary in lv["blocks"]:
		var bb := LayoutCheck.block_aabb(b)
		box = bb if first else box.merge(bb)
		first = false
	for c: Dictionary in lv["cores"]:
		var p := Vector3(float(c["x"]), float(c["y"]), float(c["z"]))
		box = AABB(p, Vector3.ZERO) if first else box.expand(p)
		first = false
	return box
