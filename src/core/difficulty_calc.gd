class_name DifficultyCalc
extends RefCounted
## Difficulty -> generator parameters (docs/03 §6, game_data/difficulty.json). Pure functions:
##   level_difficulty(world_index, level_index) = (world_base.start + (world-1) * step + rhythm.offset)
##                                                 x global_multiplier, clamped to [MIN, MAX]
##   params(d) = every curve in difficulty.curves, linearly interpolated at d
## The same formula is used by tools/validate_game_data.py and /ordino-level-designer.

const MIN_DIFFICULTY := 1.0
const MAX_DIFFICULTY := 100.0
## Curves whose values are counts (rounded to int in params()).
const INT_CURVES: PackedStringArray = [
	"block_count", "redundancy", "core_protection", "shots", "aim_preview_dots",
	"structure_count", "depth_layers",
]


static func level_difficulty(world_index: int, level_index: int, diff: Dictionary = {}) -> float:
	var d := _data(diff)
	var base: Dictionary = d["world_base"]
	var value := float(base["start"]) + (world_index - 1) * float(base["step_per_world"])
	value += float(rhythm_entry(level_index, d).get("offset", 0))
	value *= float(d.get("global_multiplier", 1.0))
	return clampf(value, MIN_DIFFICULTY, MAX_DIFFICULTY)


## Role of the n-th level of a world ("intro", "boss", ...); "" if the rhythm has no entry.
static func role_for(level_index: int, diff: Dictionary = {}) -> String:
	return str(rhythm_entry(level_index, _data(diff)).get("role", ""))


static func rhythm_entry(level_index: int, diff: Dictionary = {}) -> Dictionary:
	for r: Dictionary in _data(diff).get("rhythm", []):
		if int(r["level"]) == level_index:
			return r
	return {}


## Every curve at difficulty d. Count curves are rounded to int.
static func params(d: float, diff: Dictionary = {}) -> Dictionary:
	var out := {}
	var curves: Dictionary = _data(diff)["curves"]
	for key: String in curves:
		var v := interp(curves[key], d)
		out[key] = roundi(v) if INT_CURVES.has(key) else v
	return out


## Piecewise-linear value of [[x, y], ...] (x ascending) at x; clamped to the end points.
static func interp(points: Array, x: float) -> float:
	if points.is_empty():
		return 0.0
	if x <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var x1 := float(points[i][0])
		if x <= x1:
			var x0 := float(points[i - 1][0])
			var y0 := float(points[i - 1][1])
			var t := (x - x0) / (x1 - x0) if x1 > x0 else 1.0
			return lerpf(y0, float(points[i][1]), t)
	return float(points[-1][1])


static func _data(diff: Dictionary) -> Dictionary:
	return diff if not diff.is_empty() else GameConfig.difficulty()
