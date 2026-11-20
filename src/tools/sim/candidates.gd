class_name CandidatePipeline
extends RefCounted
## Step 9 candidate pipeline (docs/03 §8): for one level, `count` candidates (different template /
## seed), each passing every generator check (LevelGenerator.generate), then simulated (LevelSim)
## and ranked against difficulty.sim_targets. Never writes to game_data: hand-made slots and levels
## that have a file only get suggestions.
##
## Candidate i uses template tries[i % tries.size()] (the planned template first, then the other
## templates that fit the slot and differ from the planned neighbours) and base_seed + i * SEED_STEP.

const SEED_STEP := 7919
## Ranking: metrics on target first, then how far the one-shot rate is from its target range.
const METRICS: PackedStringArray = ["one_shot_solve_rate", "within_shots_rate", "keystone_collapse", "keystone_success"]


## Templates to try for a slot, planned one first.
static func templates_for(world_id: String, index: int) -> PackedStringArray:
	var world := GameConfig.world(world_id)
	var wi := int(world.get("index", 0))
	var d := DifficultyCalc.level_difficulty(wi, index)
	var role := DifficultyCalc.role_for(index)
	var plan: Array = LevelGenerator.plan_world(world_id)["templates"]
	var planned := str(plan[index - 1]) if index - 1 < plan.size() else ""
	var neighbours: Array[String] = []
	if index >= 2:
		neighbours.append(str(plan[index - 2]))
	if index < plan.size():
		neighbours.append(str(plan[index]))
	var out := PackedStringArray()
	if TemplateRegistry.has(planned) and LevelGenerator.feasible_variant(world, planned, d, role) >= 0:
		out.append(planned)
	for t in LevelGenerator.candidates(world, d):
		if not out.has(t) and not neighbours.has(t) and LevelGenerator.feasible_variant(world, t, d, role) >= 0:
			out.append(t)
	return out


## [{rank, template, seed, ok, level, report (generator), sim (LevelSim report), score}] sorted best first.
static func run_level(world_id: String, index: int, host: Node, count: int, samples: int) -> Array[Dictionary]:
	var tries := templates_for(world_id, index)
	var base := int(GameConfig.rule("generator.base_seed"))
	var out: Array[Dictionary] = []
	for i in count:
		var cand := {"template": tries[i % tries.size()] if not tries.is_empty() else "", "seed": base + i * SEED_STEP, "ok": false}
		if not str(cand["template"]).is_empty():
			var res: Dictionary = await LevelGenerator.generate(world_id, index, host,
					{"template": cand["template"], "base_seed": cand["seed"], "quiet": true})
			cand["ok"] = res["ok"]
			cand["report"] = res["report"]
			if res["ok"]:
				cand["level"] = res["expanded"]
				cand["sim"] = await LevelSim.run(res["expanded"], host, {"samples": samples, "greedy_samples": samples, "seed": cand["seed"]})
		cand["score"] = score(cand.get("sim", {}))
		out.append(cand)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return better(a["score"], b["score"]))
	for r in out.size():
		out[r]["rank"] = r + 1
	return out


## [metrics on target, -distance of the one-shot rate from its range]; {} (failed) ranks last.
static func score(sim: Dictionary) -> Array:
	if sim.is_empty():
		return [-1, -INF]
	var v: Dictionary = sim.get("verdict", {})
	var ok := 0
	for m in METRICS:
		if bool((v.get(m, {}) as Dictionary).get("ok", false)):
			ok += 1
	var dist := 0.0
	var one: Dictionary = v.get("one_shot_solve_rate", {})
	if one.has("target"):
		var lo := float(one["target"][0])
		var hi := float(one["target"][1])
		var x := float(one["value"])
		dist = maxf(0.0, maxf(lo - x, x - hi))
	return [ok, -dist]


static func better(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	return a[1] > b[1]
