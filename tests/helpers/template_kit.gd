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


## Step 8b rule: a level is either generated or its failure is reported honestly (max_attempts
## reached, every attempt failed a named check, the reason is written). Returns "" when the
## failure report is complete, else what is missing.
static func failure_report_problem(res: Dictionary) -> String:
	var r: Dictionary = res.get("report", {})
	var max_attempts := int(GameConfig.rule("generator.max_attempts"))
	if int(r.get("attempts", 0)) != max_attempts:
		return "deneme sayısı %s, sınır %d" % [r.get("attempts"), max_attempts]
	var total := 0
	for k: String in r.get("fail_counts", {}):
		total += int(r["fail_counts"][k])
	if total != max_attempts:
		return "düşen kontrol sayısı %d != %d" % [total, max_attempts]
	if (r.get("last_problems", PackedStringArray()) as PackedStringArray).is_empty():
		return "sebep yazılmamış"
	return ""


## Every static check; returns a list of human-readable problems (empty = all good).
static func problems(lv: Dictionary) -> PackedStringArray:
	return LevelChecks.flatten(LevelChecks.static_problems(lv))
