class_name LevelChecks
extends RefCounted
## Every static check of an expanded level, grouped by check (the generator counts failures per
## group): layout (LayoutCheck), support (SupportCheck), keystone (KeystoneCheck). Physics is
## separate and async (SupportCheck.physics_drift).
## Note: PackedStringArray is a value type — build each list locally, then store it.

const LAYOUT := "layout"
const SUPPORT := "support"
const KEYSTONE := "keystone"
const PHYSICS := "physics"
const GROUND := "ground"
const BUDGET := "budget"
## A block touches the ground when its lowest point is within this of the platform top (m).
const GROUND_EPS := 0.01


## {layout: [String], support: [String], keystone: [String]}; all empty = passes.
static func static_problems(lv: Dictionary) -> Dictionary:
	var layout := PackedStringArray(lv.get("_expand_warnings", PackedStringArray()))
	layout.append_array(LayoutCheck.check(lv)["issues"])
	var support := PackedStringArray()
	var s := SupportCheck.check(lv)
	if not s["ok"]:
		support.append(SupportCheck.describe(s))
	var keystone := PackedStringArray(KeystoneCheck.check(lv)["issues"])
	return {LAYOUT: layout, SUPPORT: support, KEYSTONE: keystone}


## Share of the blocks' volume that rests on the platform (lowest point at y ~ 0); cores excluded.
static func ground_contact_ratio(lv: Dictionary) -> float:
	var bodies := SupportCheck._bodies(lv)
	var total := 0.0
	var ground := 0.0
	for i in (lv.get("blocks", []) as Array).size():
		var vol := 0.0
		var low := INF
		for piece: Dictionary in bodies[i]["pieces"]:
			vol += float(piece["volume"])
			low = minf(low, (piece["aabb"] as AABB).position.y)
		total += vol
		if low <= GROUND_EPS:
			ground += vol
	return ground / total if total > 0.0 else 0.0


## Highest allowed ground_contact_ratio: difficulty curve, capped by the role's override.
static func ground_cap(d: float, role: String) -> float:
	var cap := float(DifficultyCalc.params(d).get("ground_contact_max_ratio", 1.0))
	var o: Dictionary = (GameConfig.difficulty().get("role_overrides", {}) as Dictionary).get(role, {})
	if o.has("ground_contact_max_ratio"):
		cap = minf(cap, float(o["ground_contact_max_ratio"]))
	return cap


## Most blocks a level may have: block_count x (1 + generator.budget_max_over).
static func budget_max(budget: int) -> int:
	return floori(budget * (1.0 + float(GameConfig.rule("generator.budget_max_over"))) + 1e-6)


## First failing group name, or "" when every static check passes.
static func first_failure(problems: Dictionary) -> String:
	for k: String in [LAYOUT, SUPPORT, KEYSTONE]:
		if not (problems[k] as PackedStringArray).is_empty():
			return k
	return ""


static func flatten(problems: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in problems:
		out.append_array(problems[k])
	return out
