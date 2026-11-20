class_name LevelGenerator
extends RefCounted
## Level generator (docs/03 §8 pipeline): difficulty + world + role (+ seed) -> a checked level.
##
## plan_world(): one template per level of a world, deterministic from generator.base_seed:
##   - a level that has a JSON file keeps its own template (hand-made files are never touched);
##   - otherwise a template that is in worlds.allowed_templates, written (TemplateRegistry) and whose
##     difficulty range (difficulty.templates) contains the level's difficulty;
##   - never the same template as the previous level, nor as the next level when that one is a file;
##   - only templates that can meet the level's ground_contact_max_ratio and budget limit with one
##     of their variants (feasible_variant);
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
## A hand-made slot (difficulty.handmade_levels, docs/03 §9) without a file whose candidate could not
## be generated: not an error, the level is designed by hand in Step 11.
const SOURCE_PENDING := "elle tasarlanacak (Adım 11)"
## Template label of a level file that lists its blocks by hand.
const HANDMADE := "elle"
const ID_FORMAT := "w%02d_l%02d"
## Seed mixing primes (any distinct large primes; only determinism matters).
const SEED_WORLD := 10007
const SEED_LEVEL := 101
const SEED_ATTEMPT := 7919
const SEED_BASE := 1000003
## Same template at most this many times among a world's generator levels (Sena 2026-11-20).
const MAX_SAME_TEMPLATE := 2

static var _cache: Dictionary = {}
## Disk cache of generated levels (git-ignored, user://). Key = world + level + seed + rules hash;
## any change to game_data or to the generation code makes old entries unreachable.
static var use_disk_cache: bool = true
## Tests only: treat every level as if it had no file, so the generator can still be tested on
## World 1 after its levels were baked (Step 11). The game never sets it.
static var ignore_level_files: bool = false
static var cache_dir: String = "user://level_cache/"
static var _rules_hash: String = ""
## What the rules hash covers: all game data + the code that shapes a generated level.
const HASH_DIRS: PackedStringArray = ["res://game_data/", "res://src/gameplay/level/", "res://src/gameplay/blocks/",
		"res://src/gameplay/balls/", "res://src/core/", "res://src/tools/sim/"]
const HASH_EXTENSIONS: PackedStringArray = ["json", "gd"]


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


## MD5 over every game_data JSON and generation script (sorted paths), once per session.
static func rules_hash() -> String:
	if _rules_hash.is_empty():
		var files := PackedStringArray()
		for d in HASH_DIRS:
			_collect(d, files)
		files.sort()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		for f in files:
			ctx.update(f.to_utf8_buffer())
			ctx.update(FileAccess.get_file_as_bytes(f))
		_rules_hash = ctx.finish().hex_encode()
	return _rules_hash


static func _collect(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if HASH_EXTENSIONS.has(f.get_extension()):
			out.append(dir + f)
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + sub + "/", out)


static func cache_key(world_id: String, index: int, base_seed: int, hash: String) -> String:
	return "%s_l%02d_s%d_%s" % [world_id, index, base_seed, hash.substr(0, 16)]


static func _cache_read(key: String) -> Dictionary:
	var path := cache_dir + key + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Writes the entry and removes older entries of the same level (other seeds' are kept).
static func _cache_write(key: String, world_id: String, index: int, base_seed: int, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	var prefix := "%s_l%02d_s%d_" % [world_id, index, base_seed]
	for f in DirAccess.get_files_at(cache_dir):
		if f.begins_with(prefix) and f != key + ".json":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_dir + f))
	var file := FileAccess.open(cache_dir + key + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


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
		if GameConfig.level_ids().has(id) and not ignore_level_files:
			files[k] = file_template(GameConfig.level(id))
	var templates: Array[String] = []
	var sources: Array[String] = []
	var gen_counts := {}
	var errors := PackedStringArray()
	for k in range(1, count + 1):
		if files.has(k):
			templates.append(str(files[k]))
			sources.append(SOURCE_BAKED if files[k] == HANDMADE else SOURCE_FILE)
			continue
		var d := DifficultyCalc.level_difficulty(wi, k)
		var pool := PackedStringArray()
		for t in candidates(world, d):
			if feasible_variant(world, t, d, DifficultyCalc.role_for(k)) >= 0:
				pool.append(t)
		var avoid: Array[String] = []
		if k > 1:
			avoid.append(templates[k - 2])
		if files.has(k + 1):
			avoid.append(str(files[k + 1]))
		# Selection rule (Sena 2026-11-20): a template at most MAX_SAME_TEMPLATE times among this
		# world's generator levels (hand-made slots and files do not count).
		# If the cap leaves nothing that also avoids the neighbours, the cap gives way (never the
		# no-back-to-back rule).
		var capped := PackedStringArray()
		for t in pool:
			if gen_counts.get(t, 0) < MAX_SAME_TEMPLATE and not avoid.has(t):
				capped.append(t)
		if not capped.is_empty():
			pool = capped
		# Variety: among the allowed templates prefer the ones this world has used least so far.
		var allowed := PackedStringArray()
		var least := INF
		for t in pool:
			if not avoid.has(t):
				least = minf(least, templates.count(t))
		for t in pool:
			if not avoid.has(t) and templates.count(t) == least:
				allowed.append(t)
		if allowed.is_empty() and is_handmade_slot(k):
			templates.append("")  # hand-made slot: "elle tasarlanacak", not an error (docs/03 §9)
		elif allowed.is_empty():
			errors.append("%s: şablon yok (zorluk %.0f, aday %s, kaçınılan %s)" % [level_id(wi, k), d, pool, avoid])
			templates.append("")
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_for(wi, k, 0, _base_seed(opts))
			templates.append(allowed[rng.randi_range(0, allowed.size() - 1)])
			if not is_handmade_slot(k):
				gen_counts[templates[-1]] = int(gen_counts.get(templates[-1], 0)) + 1
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
	var forced := str(opts.get("template", ""))
	var first := forced
	var neighbours: Array[String] = []
	if first.is_empty():
		var plan_t: Array = plan_world(world_id, opts)["templates"]
		first = str(plan_t[index - 1]) if index - 1 < plan_t.size() else ""
		if index >= 2:
			neighbours.append(str(plan_t[index - 2]))
		if index < plan_t.size():
			neighbours.append(str(plan_t[index]))
	var pool := PackedStringArray()
	for t in candidates(world, d):
		if feasible_variant(world, t, d, role) >= 0:
			pool.append(t)
	# A slot whose plan is a file ("elle"): e.g. the editor regenerating a baked level.
	if (first == HANDMADE or not TemplateRegistry.has(first)) and not pool.is_empty():
		first = pool[0]
	# The planned template first; if it cannot pass, the attempts move on to the other templates of
	# this slot that differ from both planned neighbours (8b). A forced template is used alone.
	var tries: Array[String] = [first]
	if forced.is_empty():
		for t in pool:
			if t != first and not neighbours.has(t):
				tries.append(t)
	var fail_counts := {LevelChecks.LAYOUT: 0, LevelChecks.SUPPORT: 0, LevelChecks.KEYSTONE: 0,
			LevelChecks.BUDGET: 0, LevelChecks.GROUND: 0, LevelChecks.PHYSICS: 0,
			LevelChecks.KEYSTONE_CLEAR: 0, LevelChecks.WITHIN_SHOTS: 0}
	var clear_target := float(GameConfig.rule("objective_defaults.clear_percent_target"))
	var within_min := float((GameConfig.difficulty().get("sim_targets", {}) as Dictionary).get("min_solve_rate_within_shots", 0.0))
	var ground_cap := LevelChecks.ground_cap(d, role)
	var budget_max := LevelChecks.budget_max(int(params["block_count"]))
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
		# Attempts are split evenly between the templates to try; inside each share, chained
		# multi-structure towers first, then single structures (8b).
		var t_index := mini(attempt * tries.size() / max_attempts, tries.size() - 1)
		var share_start := ceili(float(t_index) * max_attempts / tries.size())
		var share_len := maxi(1, ceili(float(t_index + 1) * max_attempts / tries.size()) - share_start)
		var single := (attempt - share_start) >= share_len / 2.0
		var template := tries[t_index]
		var level := _build_level(world, wi, index, d, role, params, overrides, template, pool, rng, attempt, single)
		var expanded := LevelExpander.expand(level)
		var problems := LevelChecks.static_problems(expanded)
		var failed := LevelChecks.first_failure(problems)
		var n_blocks := (expanded["blocks"] as Array).size()
		var ground := LevelChecks.ground_contact_ratio(expanded)
		if failed.is_empty() and n_blocks > budget_max:
			failed = LevelChecks.BUDGET
			problems[LevelChecks.BUDGET] = PackedStringArray(["%d blok > üst sınır %d" % [n_blocks, budget_max]])
		if failed.is_empty() and ground > ground_cap + 1e-6:
			failed = LevelChecks.GROUND
			problems[LevelChecks.GROUND] = PackedStringArray(["yere değen hacim %%%d > %%%d" % [roundi(ground * 100.0), roundi(ground_cap * 100.0)]])
		if failed.is_empty():
			var phys: Dictionary = await SupportCheck.physics_drift(expanded, node)
			if not phys["ok"]:
				failed = LevelChecks.PHYSICS
				problems[LevelChecks.PHYSICS] = PackedStringArray(["%s %.4f m kaydı" % [phys["worst"], phys["max_drift"]]])
		var key_share := 0.0
		var within := 0.0
		if failed.is_empty():
			# 8b: a direct keystone shot must clear the objective (difficulty = finding / hitting it).
			var clears: Dictionary = await LevelSim.keystone_clears(expanded, node, int(GameConfig.rule("generator.keystone_shots")), rng)
			key_share = _best_keystone_share(clears, clear_target)
			if key_share < keystone_share_required(role):
				failed = LevelChecks.KEYSTONE_CLEAR
				problems[LevelChecks.KEYSTONE_CLEAR] = PackedStringArray(["keystone atışı %%%d hedefi tutmuyor: %s" % [roundi(clear_target * 100.0), _clears_text(clears)]])
		if failed.is_empty():
			within = await LevelSim.within_shots_rate(expanded, node, int(GameConfig.rule("generator.sim_greedy_samples")), rng,
					int(GameConfig.rule("generator.sim_batch")))
			if within < within_min:
				failed = LevelChecks.WITHIN_SHOTS
				problems[LevelChecks.WITHIN_SHOTS] = PackedStringArray(["gülleyle çözüm %%%d < %%%d" % [roundi(within * 100.0), roundi(within_min * 100.0)]])
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
		report["ground"] = ground
		report["template_planned"] = first
		report["keystone_share"] = key_share
		report["within_shots"] = within
		report["single_fallback"] = single and (level["structures"] as Array).size() == 1 and 				maxi(int(params.get("structure_count", 1)), int(overrides.get("structure_count_min", 1))) > 1
		report["ground_cap"] = ground_cap
		var vars: Array = []
		for st: Dictionary in level["structures"]:
			vars.append(st.get("variant", {}))
		report["variants"] = vars
		if float(report["fill"]) < float(GameConfig.rule("generator.budget_warn_below")):
			(report["warnings"] as Array).append("bütçe %%%d dolu (%d / %d blok)" % [
					roundi(float(report["fill"]) * 100.0), used, int(report["budget"])])
		return {"ok": true, "level": level, "expanded": expanded, "report": report}
	var msg := "LevelGenerator %s: %d denemede geçen kule yok; düşen kontroller %s; son sorunlar: %s" % [
			level_id(wi, index), max_attempts, fail_counts, "; ".join(report["last_problems"])]
	if bool(opts.get("quiet", false)):
		push_warning(msg)  # hand-made slot: only a candidate failed, not an error
	else:
		push_error(msg)
	return {"ok": false, "level": {}, "expanded": {}, "report": report}


## What the game plays for `id`: {ok, level (expanded), source, report}.
static func resolve(id: String, node: Node) -> Dictionary:
	if GameConfig.level_ids().has(id) and not ignore_level_files:
		var lv := GameConfig.level(id)
		var src := SOURCE_BAKED if file_template(lv) == HANDMADE else SOURCE_FILE
		return {"ok": true, "level": LevelExpander.expand(lv), "source": src, "report": {}}
	if _cache.has(id):
		return _cache[id]
	var wi := parse_id(id)
	var world := world_by_index(wi.x)
	if world.is_empty() or wi.y < 1 or wi.y > int(world.get("level_count", 0)):
		return {"ok": false, "level": {}, "source": "", "report": {}}
	var base_seed := int(GameConfig.rule("generator.base_seed"))
	var key := cache_key(str(world["id"]), wi.y, base_seed, rules_hash())
	if use_disk_cache:
		var cached := _cache_read(key)
		if not cached.is_empty():
			cached["from_disk_cache"] = true
			_cache[id] = cached
			return cached
	var handmade := is_handmade_slot(wi.y)
	var res: Dictionary = await generate(str(world["id"]), wi.y, node, {"quiet": handmade})
	var out := {"ok": res["ok"], "level": res["expanded"], "report": res["report"],
			"source": SOURCE_CANDIDATE if handmade else SOURCE_GENERATED}
	if handmade and not res["ok"]:
		out["source"] = SOURCE_PENDING
		out["pending"] = true
	# Failures are cached too (with their report), so N/B does not retry 12 attempts every time.
	_cache[id] = out
	if use_disk_cache:
		_cache_write(key, str(world["id"]), wi.y, base_seed, out)
	return out


## Short one-line summary for the dev panel / HUD.
static func describe(res: Dictionary) -> String:
	var r: Dictionary = res.get("report", {})
	if r.is_empty():
		return str(res.get("source", ""))
	var text := "%s · %s · deneme %d · bütçe %%%d" % [res.get("source", ""), "+".join(PackedStringArray(r.get("templates", []))),
			int(r.get("attempts", 0)), roundi(float(r.get("fill", 0.0)) * 100.0)]
	var planned := str(r.get("template_planned", ""))
	if not planned.is_empty() and not (r.get("templates", []) as Array).is_empty() and str(r["templates"][0]) != planned:
		text += " · plan %s geçmedi" % planned
	if bool(r.get("single_fallback", false)):
		text += " · zincir kurulamadı, tek yapı"
	if bool(res.get("from_disk_cache", false)):
		text += " · önbellekten"
	if not (r.get("warnings", []) as Array).is_empty():
		text += " · UYARI: " + "; ".join(PackedStringArray(r["warnings"]))
	return text


# --- Building one attempt ---

static func _build_level(world: Dictionary, wi: int, index: int, d: float, role: String, params: Dictionary,
		overrides: Dictionary, first: String, pool: PackedStringArray, rng: RandomNumberGenerator,
		attempt: int = 0, single: bool = false) -> Dictionary:
	var budget := int(params["block_count"])
	var count := maxi(1, maxi(int(params.get("structure_count", 1)), int(overrides.get("structure_count_min", 1))))
	count = mini(count, int(GameConfig.rule("generator.max_structures")))
	if single:
		count = 1
	var min_count := count  # never fewer (boss: role_overrides.boss.structure_count_min)
	var structs: Array[Dictionary] = []
	for k in count:
		var t := first if k == 0 else _pick_other(pool, structs, first, rng)
		structs.append(_structure(t, budget / count, rng, attempt, world, d, role))
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
		if single or float(used) / maxf(1.0, budget) >= warn or structs.size() >= int(GameConfig.rule("generator.max_structures")):
			break
		structs.append(_structure(_pick_other(pool, structs, first, rng), maxi(1, budget - used), rng, attempt, world, d, role))
	var final_blocks: Array = LevelExpander.expand(level)["blocks"]
	level["platform"] = LayoutCheck.platform_for(final_blocks)
	level["platform"]["style"] = str(world.get("platform_style", ""))
	return level


## Keystone shots that must reach the objective on the best keystone, for a role (K-032).
static func keystone_share_required(role: String) -> float:
	var by_role: Dictionary = GameConfig.rule("generator.keystone_shot_success_share_by_role")
	return float(by_role.get(role, GameConfig.rule("generator.keystone_shot_success_share")))


## Share of shots reaching `target` on the best keystone.
static func _best_keystone_share(clears: Dictionary, target: float) -> float:
	var best := 0.0
	for k: String in clears:
		var arr: Array = clears[k]
		var ok := 0
		for r in arr:
			if float(r) >= target:
				ok += 1
		best = maxf(best, float(ok) / maxf(1, arr.size()))
	return best


static func _clears_text(clears: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in clears:
		var pct := PackedStringArray()
		for r in clears[k]:
			pct.append("%%%d" % roundi(float(r) * 100.0))
		parts.append("%s %s" % [k, "/".join(pct)])
	return ", ".join(parts)


## A structure call with the template variant for this attempt: the first feasible variant
## (ground cap + budget limit), then the next ones on later attempts.
static func _structure(t: String, block_count: int, rng: RandomNumberGenerator, attempt: int,
		world: Dictionary, d: float, role: String) -> Dictionary:
	var tpl := TemplateRegistry.create(t)
	var vars: Array[Dictionary] = tpl.variants() if tpl else [{}]
	var start := maxi(0, feasible_variant(world, t, d, role))
	var v: Dictionary = vars[(start + attempt) % vars.size()]
	var params := {"block_count": block_count}
	params.merge(v, true)
	return {"template": t, "seed": rng.randi(), "params": params, "variant": v.duplicate()}


## Index of the first variant of template t that, alone at difficulty d with the full budget,
## stays within the ground_contact_max_ratio of the role and the budget limit; -1 if none.
static func feasible_variant(world: Dictionary, t: String, d: float, role: String) -> int:
	var tpl := TemplateRegistry.create(t)
	if tpl == null:
		return -1
	var budget := int(DifficultyCalc.params(d)["block_count"])
	var cap := LevelChecks.ground_cap(d, role)
	var vars := tpl.variants()
	for i in vars.size():
		var params := {"block_count": budget}
		params.merge(vars[i], true)
		var lv := {"id": "probe", "world": str(world.get("id", "")), "index": 1, "difficulty": d, "role": role,
				"structures": [{"template": t, "seed": 0, "params": params}], "blocks": [], "keystones": [], "cores": []}
		var ex := LevelExpander.expand(lv)
		if (ex["blocks"] as Array).size() <= LevelChecks.budget_max(budget) and LevelChecks.ground_contact_ratio(ex) <= cap + 1e-6:
			return i
	return -1


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
	# Chain (docs/03 §5, 8b): the next structures stand on the side the first one falls to — the side
	# of its keystone (break the keystone and the plank / arch / wall / deck tips that way).
	var order: Array[int] = []
	for i in boxes.size():
		order.append(i)
	if boxes.size() > 1 and _keystone_side(level, 0) < 0.0:
		order.reverse()
	var left := -total / 2.0
	for i in order:
		var st: Dictionary = level["structures"][i]
		st["x"] = snappedf(left - boxes[i].position.x, 0.001)
		st["z"] = 0.0
		st["ry"] = 0.0
		left += boxes[i].size.x + gap


## -1 / +1: which side of structure `i` (alone, at the origin) its first keystone is on.
static func _keystone_side(level: Dictionary, i: int) -> float:
	var single := level.duplicate(true)
	var s: Dictionary = (level["structures"][i] as Dictionary).duplicate(true)
	s["x"] = 0.0
	s["z"] = 0.0
	s["ry"] = 0.0
	single["structures"] = [s]
	var ex := LevelExpander.expand(single)
	var centre := _bounds(ex).get_center().x
	for b: Dictionary in ex["blocks"]:
		if (ex["keystones"] as Array).has(b["id"]):
			return -1.0 if float(b["x"]) < centre else 1.0
	return 1.0


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
