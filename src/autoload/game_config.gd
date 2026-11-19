extends Node
## Loads every game_data/*.json once at startup and gives read-only access (docs/02 §4.1, §5).
## Keys starting with "_" are documentation and are stripped on load.
## Note: Godot's JSON parser returns every number as float; cast with int() where an integer is needed.
## Full schema validation lives in tools/validate_game_data.py; here we only check what the game needs to run.

const DATA_DIR := "res://game_data/"
const LEVELS_DIR := "res://game_data/levels/"

## Rule paths the game reads directly. Missing one = startup error (no silent defaults: K-004).
const REQUIRED_RULES: PackedStringArray = [
	"aim.mode", "aim.default_preview_dots", "aim.aim_smoothing",
	"aim.preview_dot_interval_sec", "aim.arc", "aim.on_miss",
	"aim.drag_deg_per_px", "aim.drag_pitch_min_deg", "aim.drag_pitch_max_deg",
	"aim.drag_yaw_max_deg", "aim.drag_dead_zone_px",
	"cannon.position",
	"objective_defaults.core_shape", "objective_defaults.core_material",
	"objective_defaults.type", "objective_defaults.clear_percent_target",
	"objective_defaults.clear_measure", "objective_defaults.broken_counts_as_cleared",
	"shots.default_per_level", "shots.refire_cooldown_sec", "feel.slowmo_enabled",
	"feel.final_slowmo_scale", "feel.final_slowmo_duration_sec",
	"stars.mode", "stars.three_star_min_shots_left_offset", "stars.two_star_min_shots_left_offset",
	"physics.gravity", "physics.tick_rate", "physics.settle_timeout_sec",
	"physics.settle_linear_velocity_threshold", "physics.fall_kill_y", "physics.spawn_sleeping",
	"physics.max_active_bodies", "physics.edge_rule", "physics.edge_margin",
	"camera.fov_deg", "camera.pitch_deg", "camera.yaw_deg", "camera.distance",
	"camera.look_at_height", "camera.keep_aspect",
	"feel.shake_max_offset", "feel.shake_max_rotation_deg", "feel.shake_decay",
	"feel.max_concurrent_bursts", "feel.shake_trauma_per_impulse", "feel.spark_min_impulse",
	"feel.crack_hp_ratio", "feel.shake_frequency",
	"feel.spark_amount", "feel.spark_lifetime_sec", "feel.spark_speed", "feel.spark_size",
	"quality.default",
	"platform.thickness", "platform.friction", "platform.bounce",
	"dev.start_level_id", "dev.play_area_guide", "dev.stress_block_count", "dev.nudge_impulse",
	"dev.panel_open_touches", "dev.panel",
	"dev.stress_columns", "dev.stress_rows", "dev.perf_warn_fps",
]
const VALID_AIM_MODES: PackedStringArray = ["tap_target", "drag_release"]
const VALID_EDGE_RULES: PackedStringArray = ["com_outside_platform"]
const VALID_KEEP_ASPECT: PackedStringArray = ["width", "height"]

var errors: PackedStringArray = []
## Non-fatal data issues (e.g. a special ball whose behaviour arrives in a later phase).
var warnings: PackedStringArray = []

var _rules: Dictionary = {}
var _materials: Dictionary = {}
var _shapes: Dictionary = {}
var _balls: Dictionary = {}       # id -> ball dict
var _worlds: Dictionary = {}      # id -> world dict
var _difficulty: Dictionary = {}
var _economy: Dictionary = {}
var _level_paths: Dictionary = {} # level id -> res:// path
var _level_cache: Dictionary = {}
## Dev Panel: original JSON value per panel entry label, recorded on the first live change.
var _dev_original: Dictionary = {}


func _ready() -> void:
	load_all()
	for w in warnings:
		push_warning("GameConfig: " + w)
	if is_valid():
		apply_physics_settings()
		print("GameConfig OK: ", summary())
	else:
		for e in errors:
			push_error("GameConfig: " + e)


func is_valid() -> bool:
	return errors.is_empty()


func load_all() -> void:
	errors.clear()
	warnings.clear()
	_level_cache.clear()
	_dev_original.clear()
	_rules = _load_json("rules.json")
	_materials = _load_json("materials.json").get("materials", {})
	_shapes = _load_json("shapes.json").get("shapes", {})
	_difficulty = _load_json("difficulty.json")
	_economy = _load_json("economy.json")
	_balls = _index_by_id(_load_json("balls.json").get("balls", []), "balls.json")
	_worlds = _index_by_id(_load_json("worlds.json").get("worlds", []), "worlds.json")
	_level_paths.clear()
	_scan_levels(LEVELS_DIR)
	_check_rules()
	_validate_references()


func summary() -> String:
	return "%d malzeme, %d şekil, %d top, %d dünya, %d bölüm" % [
		_materials.size(), _shapes.size(), _balls.size(), _worlds.size(), _level_paths.size()]


## Applies rules.physics to the running engine (gravity of the default 3D space, physics tick rate).
func apply_physics_settings() -> void:
	Engine.physics_ticks_per_second = int(rule("physics.tick_rate"))
	var world := get_tree().root.find_world_3d()
	if world:
		PhysicsServer3D.area_set_param(world.space, PhysicsServer3D.AREA_PARAM_GRAVITY,
				float(rule("physics.gravity")))


# --- Accessors (read-only: callers must not mutate returned dictionaries) ---

func rules() -> Dictionary:
	return _rules


## Dotted path lookup, e.g. rule("physics.gravity"). Returns null if missing.
func rule(path: String) -> Variant:
	var node: Variant = _rules
	for part in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(part):
			return null
		node = (node as Dictionary)[part]
	return node


func material(id: String) -> Dictionary:
	return _materials.get(id, {})


func shape(id: String) -> Dictionary:
	return _shapes.get(id, {})


func ball(id: String) -> Dictionary:
	return _balls.get(id, {})


## The ball the player owns from the start (balls.json unlock.type == "start"; K-005: heavy).
func starting_ball_id() -> String:
	for id: String in _balls:
		if str((_balls[id] as Dictionary).get("unlock", {}).get("type")) == "start":
			return id
	return ""


func world(id: String) -> Dictionary:
	return _worlds.get(id, {})


func difficulty() -> Dictionary:
	return _difficulty


func economy() -> Dictionary:
	return _economy


func level_ids() -> PackedStringArray:
	var ids := PackedStringArray(_level_paths.keys())
	ids.sort()
	return ids


## Loads (and caches) one level file. Returns {} and records an error if it does not exist.
func level(id: String) -> Dictionary:
	if _level_cache.has(id):
		return _level_cache[id]
	if not _level_paths.has(id):
		errors.append("bölüm bulunamadı: " + id)
		return {}
	var data: Dictionary = _parse_file(_level_paths[id])
	_level_cache[id] = data
	return data


# --- Dev Panel (live tuning, docs/02 §5.3). Entries come from rules.dev.panel. ---
# Changes live only in memory: they survive a level restart (R) but not quitting the game,
# unless DevPanel writes them back to the JSON files.

## Current value of a panel entry (the first id's value for multi-id entries).
func dev_get(entry: Dictionary) -> float:
	var targets := _dev_targets(entry)
	if targets.is_empty():
		return 0.0
	return float(_dig(targets[0], str(entry["key"])))


func dev_set(entry: Dictionary, value: float) -> void:
	var label := str(entry["label"])
	if not _dev_original.has(label):
		_dev_original[label] = dev_get(entry)
	var parts := str(entry["key"]).split(".")
	for target in _dev_targets(entry):
		var node: Dictionary = target
		for i in parts.size() - 1:
			node = node[parts[i]]
		node[parts[parts.size() - 1]] = value
	if str(entry["file"]) == "rules" and str(entry["key"]).begins_with("physics."):
		apply_physics_settings()


## Labels of entries whose value differs from what was loaded from JSON.
func dev_changed_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in rule("dev.panel"):
		var label := str(entry["label"])
		if _dev_original.has(label) and not is_equal_approx(float(_dev_original[label]), dev_get(entry)):
			out.append(label)
	return out


## Source file for a panel entry's `file` field.
func dev_file_path(entry: Dictionary) -> String:
	return DATA_DIR + str(entry["file"]) + ".json"


func _dev_targets(entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match str(entry["file"]):
		"rules":
			out.append(_rules)
		"materials":
			for id: String in entry.get("ids", []):
				if _materials.has(id):
					out.append(_materials[id])
		"balls":
			for id: String in entry.get("ids", []):
				if _balls.has(id):
					out.append(_balls[id])
	return out


func _dig(root: Dictionary, path: String) -> Variant:
	var node: Variant = root
	for part in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(part):
			return null
		node = (node as Dictionary)[part]
	return node


# --- Internals ---

func _load_json(file_name: String) -> Dictionary:
	return _parse_file(DATA_DIR + file_name)


func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("dosya yok: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: JSON hatası satır %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		errors.append(path + ": kök nesne {} olmalı")
		return {}
	return _strip_doc_keys(json.data)


## Recursively removes "_"-prefixed documentation keys.
func _strip_doc_keys(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key in (value as Dictionary):
			if str(key).begins_with("_"):
				continue
			out[key] = _strip_doc_keys(value[key])
		return out
	if value is Array:
		var arr: Array = []
		for item in (value as Array):
			arr.append(_strip_doc_keys(item))
		return arr
	return value


func _index_by_id(items: Array, source: String) -> Dictionary:
	var out: Dictionary = {}
	for item in items:
		if item is Dictionary and (item as Dictionary).has("id"):
			out[item["id"]] = item
		else:
			errors.append(source + ": 'id' alanı olmayan öğe")
	return out


func _scan_levels(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append("bölüm klasörü açılamadı: " + dir_path)
		return
	for sub in dir.get_directories():
		_scan_levels(dir_path.path_join(sub))
	for file in dir.get_files():
		if file.get_extension() == "json":
			_level_paths[file.get_basename()] = dir_path.path_join(file)


## Cross-file references (ConfigValidator). Parses every level once (they are cached).
func _validate_references() -> void:
	var levels: Dictionary = {}
	for id: String in _level_paths:
		levels[id] = level(id)
	var v := ConfigValidator.new().validate({
		"rules": _rules, "materials": _materials, "shapes": _shapes, "balls": _balls,
		"worlds": _worlds, "economy": _economy, "levels": levels,
	})
	errors.append_array(v.errors)
	warnings.append_array(v.warnings)


func _check_rules() -> void:
	for path in REQUIRED_RULES:
		if rule(path) == null:
			errors.append("rules.json eksik anahtar: " + path)
	if rule("aim.mode") != null and not VALID_AIM_MODES.has(str(rule("aim.mode"))):
		errors.append("rules.aim.mode geçersiz: %s (geçerli: %s)" % [rule("aim.mode"), ", ".join(VALID_AIM_MODES)])
	if rule("physics.edge_rule") != null and not VALID_EDGE_RULES.has(str(rule("physics.edge_rule"))):
		errors.append("rules.physics.edge_rule geçersiz: %s" % rule("physics.edge_rule"))
	if rule("camera.keep_aspect") != null and not VALID_KEEP_ASPECT.has(str(rule("camera.keep_aspect"))):
		errors.append("rules.camera.keep_aspect geçersiz: %s" % rule("camera.keep_aspect"))
	if not _balls.has("heavy"):
		errors.append("balls.json: 'heavy' (başlangıç topu) yok")
	if starting_ball_id().is_empty():
		errors.append("balls.json: unlock.type = 'start' olan top yok")
