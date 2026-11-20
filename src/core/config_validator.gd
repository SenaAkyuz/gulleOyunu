class_name ConfigValidator
extends RefCounted
## In-game check of game_data (docs/02 §4.1, Faz 2 Step 2): everything the game needs at runtime,
## mainly the references BETWEEN files (a level's shape/material exists, a world's palette names real
## materials, a ball's damage_mult names real materials, …). The full schema check stays in
## tools/validate_game_data.py; keep the two consistent when adding rules.
## Pure function over plain dictionaries so GUT can feed it broken data. Messages are Turkish.

const VALID_COLLIDERS: PackedStringArray = ["box", "sphere", "cylinder", "convex"]
## K-030: the Golden Core never ends a level -> no drop_core / drop_all_cores objectives.
const VALID_OBJECTIVES: PackedStringArray = ["clear_percent", "shatter_crystals"]
const VALID_UNLOCKS: PackedStringArray = ["start", "level_cleared"]
const MATERIAL_NUMBERS: PackedStringArray = ["density", "hp", "impact_threshold", "friction", "bounce"]
const BALL_NUMBERS: PackedStringArray = ["mass", "radius", "launch_speed", "max_life_sec"]
const BEHAVIOR_PATH := "res://src/gameplay/balls/behaviors/%s_behavior.gd"
const STAR_KEYS: PackedStringArray = ["1", "2", "3"]
const MIN_CONVEX_POINTS := 4

var errors: PackedStringArray = []
var warnings: PackedStringArray = []


## data keys: rules, materials, shapes, balls (id -> ball), worlds (id -> world), economy,
## levels (id -> level). Returns self so callers can read errors / warnings.
func validate(data: Dictionary) -> ConfigValidator:
	errors.clear()
	warnings.clear()
	var materials: Dictionary = data.get("materials", {})
	var shapes: Dictionary = data.get("shapes", {})
	var balls: Dictionary = data.get("balls", {})
	var worlds: Dictionary = data.get("worlds", {})
	var levels: Dictionary = data.get("levels", {})
	_check_materials(materials)
	_check_shapes(shapes)
	_check_balls(balls, materials)
	_check_worlds(worlds, materials)
	_check_economy(data.get("economy", {}))
	_check_rules_refs(data.get("rules", {}), materials, shapes, balls, levels)
	for id: String in levels:
		_check_level(id, levels[id], data.get("rules", {}), materials, shapes, balls, worlds)
	return self


func _check_materials(materials: Dictionary) -> void:
	if materials.is_empty():
		errors.append("materials.json: malzeme yok")
	for id: String in materials:
		var m: Dictionary = materials[id]
		for key in MATERIAL_NUMBERS:
			if not _is_num(m.get(key)):
				errors.append("materials.%s: '%s' sayı olmalı" % [id, key])
		if _is_num(m.get("density")) and float(m["density"]) <= 0.0:
			errors.append("materials.%s: density > 0 olmalı" % id)
		if m.has("coin_on_break") and not (_is_num(m["coin_on_break"]) and float(m["coin_on_break"]) >= 0.0):
			errors.append("materials.%s: coin_on_break 0 veya pozitif olmalı" % id)


func _check_shapes(shapes: Dictionary) -> void:
	for id: String in shapes:
		var s: Dictionary = shapes[id]
		if not _is_positive_vec3(s.get("size")):
			errors.append("shapes.%s: size [x, y, z] (pozitif) olmalı" % id)
		var colliders: Array = s.get("colliders", [])
		if colliders.is_empty():
			errors.append("shapes.%s: colliders boş" % id)
		for c: Dictionary in colliders:
			var type := str(c.get("type"))
			if not VALID_COLLIDERS.has(type):
				errors.append("shapes.%s: geçersiz collider tipi '%s'" % [id, type])
			elif type == "box" and not _is_positive_vec3(c.get("size")):
				errors.append("shapes.%s: box collider size [x, y, z] olmalı" % id)
			elif (type == "sphere" or type == "cylinder") and not _is_num(c.get("radius")):
				errors.append("shapes.%s: %s collider radius olmalı" % [id, type])
			elif type == "convex" and (c.get("points", []) as Array).size() < MIN_CONVEX_POINTS:
				errors.append("shapes.%s: convex en az %d nokta olmalı" % [id, MIN_CONVEX_POINTS])


func _check_balls(balls: Dictionary, materials: Dictionary) -> void:
	var has_start := false
	for id: String in balls:
		var b: Dictionary = balls[id]
		for key in BALL_NUMBERS:
			if not _is_num(b.get(key)) or float(b[key]) <= 0.0:
				errors.append("balls.%s: '%s' pozitif sayı olmalı" % [id, key])
		for mat: String in (b.get("damage_mult", {}) as Dictionary):
			if not materials.has(mat):
				errors.append("balls.%s.damage_mult: '%s' materials.json'da yok" % [id, mat])
		var unlock: Dictionary = b.get("unlock", {})
		var utype := str(unlock.get("type"))
		if not VALID_UNLOCKS.has(utype):
			errors.append("balls.%s: geçersiz unlock.type '%s'" % [id, utype])
		has_start = has_start or utype == "start"
		if not ResourceLoader.exists(BEHAVIOR_PATH % str(b.get("behavior"))):
			# Special-ball behaviours arrive in Faz 5; the ball just cannot be fired until then.
			warnings.append("balls.%s: davranış dosyası yok (%s)" % [id, BEHAVIOR_PATH % str(b.get("behavior"))])
	if not has_start:
		errors.append("balls.json: unlock.type = 'start' olan top yok")


func _check_worlds(worlds: Dictionary, materials: Dictionary) -> void:
	var last_required := -1
	for id: String in worlds:
		var w: Dictionary = worlds[id]
		for mat: String in (w.get("palette", {}) as Dictionary):
			if not materials.has(mat):
				errors.append("worlds.%s.palette: '%s' materials.json'da yok" % [id, mat])
		var req := int(w.get("unlock_stars_required", 0))
		if req < last_required:
			errors.append("worlds.%s: unlock_stars_required önceki dünyadan küçük" % id)
		last_required = req


func _check_economy(economy: Dictionary) -> void:
	var gold: Variant = economy.get("currencies", {}).get("gold", {}).get("start_amount")
	if not _is_num(gold) or float(gold) < 0.0:
		errors.append("economy.currencies.gold.start_amount 0 veya pozitif sayı olmalı")
	var rewards: Dictionary = economy.get("rewards", {})
	var stars: Dictionary = rewards.get("stars", {})
	for k in STAR_KEYS:
		if not _is_num(stars.get(k)):
			errors.append("economy.rewards.stars.%s sayı olmalı" % k)
	if _is_num(stars.get("1")) and _is_num(stars.get("2")) and _is_num(stars.get("3")):
		if not (float(stars["1"]) <= float(stars["2"]) and float(stars["2"]) <= float(stars["3"])):
			errors.append("economy.rewards.stars: 1 ≤ 2 ≤ 3 olmalı")
	var ratio: Variant = rewards.get("replay_ratio")
	if not _is_num(ratio) or float(ratio) < 0.0 or float(ratio) > 1.0:
		errors.append("economy.rewards.replay_ratio 0..1 olmalı")
	for key in ["core_jackpot_gold", "crystal_coin_cap_per_level", "world_complete_bonus",
			"world_perfect_bonus", "boss_mult"]:
		if not _is_num(rewards.get(key)) or float(rewards[key]) < 0.0:
			errors.append("economy.rewards.%s 0 veya pozitif sayı olmalı" % key)


func _check_rules_refs(rules: Dictionary, materials: Dictionary, shapes: Dictionary,
		balls: Dictionary, levels: Dictionary) -> void:
	var obj: Dictionary = rules.get("objective_defaults", {})
	if not shapes.has(str(obj.get("core_shape"))):
		errors.append("rules.objective_defaults.core_shape '%s' shapes.json'da yok" % obj.get("core_shape"))
	if not materials.has(str(obj.get("core_material"))):
		errors.append("rules.objective_defaults.core_material '%s' materials.json'da yok" % obj.get("core_material"))
	var start := str(rules.get("dev", {}).get("start_level_id"))
	if not levels.has(start):
		errors.append("rules.dev.start_level_id '%s' için bölüm dosyası yok" % start)
	for entry: Dictionary in rules.get("dev", {}).get("panel", []):
		var pool: Dictionary = {"materials": materials, "balls": balls}.get(str(entry.get("file")), {})
		for id: String in entry.get("ids", []):
			if not pool.has(id):
				errors.append("rules.dev.panel '%s': bilinmeyen id '%s'" % [entry.get("label"), id])


func _check_level(id: String, lv: Dictionary, rules: Dictionary, materials: Dictionary,
		shapes: Dictionary, balls: Dictionary, worlds: Dictionary) -> void:
	var where := "levels/%s" % id
	if str(lv.get("id")) != id:
		errors.append("%s: id alanı dosya adıyla aynı olmalı" % where)
	if not worlds.has(str(lv.get("world"))):
		errors.append("%s: dünya '%s' worlds.json'da yok" % [where, lv.get("world")])
	var objective: Dictionary = lv.get("objective", {})
	var otype := str(objective.get("type", rules.get("objective_defaults", {}).get("type")))
	if not VALID_OBJECTIVES.has(otype):
		errors.append("%s: geçersiz objective.type '%s'" % [where, otype])
	if objective.has("target") and not (_is_num(objective["target"]) and float(objective["target"]) > 0.0 and float(objective["target"]) <= 1.0):
		errors.append("%s: objective.target 0 < x ≤ 1 olmalı" % where)
	var plat: Dictionary = lv.get("platform", {})
	for key in ["width", "depth"]:
		if not _is_num(plat.get(key)) or float(plat[key]) <= 0.0:
			errors.append("%s: platform.%s pozitif sayı olmalı" % [where, key])
	var ids: Dictionary = {}
	for b: Dictionary in lv.get("blocks", []):
		var bid := str(b.get("id"))
		if ids.has(bid):
			errors.append("%s: tekrar eden blok id '%s'" % [where, bid])
		ids[bid] = true
		if not shapes.has(str(b.get("shape"))):
			errors.append("%s: blok %s şekli '%s' shapes.json'da yok" % [where, bid, b.get("shape")])
		if not materials.has(str(b.get("mat"))):
			errors.append("%s: blok %s malzemesi '%s' materials.json'da yok" % [where, bid, b.get("mat")])
		if not (_is_num(b.get("x")) and _is_num(b.get("y")) and _is_num(b.get("z"))):
			errors.append("%s: blok %s x, y, z sayı olmalı" % [where, bid])
	var baked := bool(lv.get("baked", false))
	if baked:
		for k: String in lv.get("keystones", []):
			if not ids.has(k):
				errors.append("%s: keystone '%s' blok listesinde yok" % [where, k])
		var tutorial: Variant = lv.get("tutorial")
		if tutorial is Dictionary and (tutorial as Dictionary).has("target_block") \
				and not ids.has(str(tutorial["target_block"])):
			errors.append("%s: tutorial.target_block '%s' blok listesinde yok" % [where, tutorial["target_block"]])
	var cam: Variant = lv.get("camera_override")
	if cam is Dictionary:
		for key: String in (cam as Dictionary):
			if not (rules.get("camera", {}) as Dictionary).has(key):
				errors.append("%s: camera_override.%s rules.camera'da olmayan anahtar" % [where, key])
	for ball_id: String in (lv.get("free_balls", {}) as Dictionary):
		if not balls.has(ball_id):
			errors.append("%s: free_balls '%s' geçersiz top" % [where, ball_id])


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


static func _is_positive_vec3(v: Variant) -> bool:
	if not (v is Array) or (v as Array).size() != 3:
		return false
	for x: Variant in v:
		if not _is_num(x) or float(x) <= 0.0:
			return false
	return true
