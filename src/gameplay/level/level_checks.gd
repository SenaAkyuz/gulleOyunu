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
