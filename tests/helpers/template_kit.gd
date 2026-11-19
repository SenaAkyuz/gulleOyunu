extends RefCounted
## Builds a one-structure test level for a template and runs every placement check on it:
## LayoutCheck (area, edge inset, keystone, crystal), SupportCheck (static balance),
## KeystoneCheck (camera visibility + cannon reachability). Physics is run separately (async).


static func level(template_id: String, difficulty: float, seed: int, params: Dictionary = {}) -> Dictionary:
	var lv := {"id": "kit_%s_%d_%d" % [template_id, difficulty, seed], "world": "akdeniz", "index": 1,
			"difficulty": difficulty, "objective": {"type": "clear_percent"},
			"structures": [{"template": template_id, "x": 0, "z": 0, "ry": 0, "seed": seed, "params": params}],
			"blocks": [], "keystones": [], "cores": []}
	var out := LevelExpander.expand(lv)
	out["platform"] = LayoutCheck.platform_for(out["blocks"])
	return out


## Every static check; returns a list of human-readable problems (empty = all good).
static func problems(lv: Dictionary) -> PackedStringArray:
	return LevelChecks.flatten(LevelChecks.static_problems(lv))
