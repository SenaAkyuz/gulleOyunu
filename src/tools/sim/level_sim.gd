class_name LevelSim
extends RefCounted
## Headless level simulation (docs/03 §8.1, Faz 3 Step 8). Fires real Balls at real blocks (damage,
## breaking, edge rule) and measures:
##   one_shot_solve_rate  : share of `samples` single shots that reach the objective (clear_percent).
##                          Targets: random points on block faces visible from the default camera
##                          (what a player can tap), tap_target arc (rules.aim.arc).
##   keystone             : one shot at each keystone (centre of its camera-facing samples);
##                          success = objective met; collapse = cleared share after that shot.
##   jackpot_rate         : share of solved single shots where the Golden Core also fell.
##   within_shots_rate    : share of greedy runs that solve within level.shots — first shot random,
##                          then each shot at the biggest block still on the platform.
##   collapse_ratio_mean  : mean cleared share after one random shot.
## Speed: `batch` copies of the level run side by side in one physics world (COPY_SPACING apart);
## run from the CLI with --fixed-fps so every frame is one physics step as fast as the CPU allows.
## Results are only measured and compared with difficulty.sim_targets — nothing is changed.

const BALL_SCENE := preload("res://src/gameplay/balls/ball.tscn")
## Distance between parallel copies (m). Far beyond any shot's sideways drift.
const COPY_SPACING := 40.0
## Physics frames before the first shot (TowerBuilder releases bodies after the first tick).
const RELEASE_FRAMES := 3
const KIND_RANDOM := "random"
const KIND_KEYSTONE := "keystone"
const KIND_GREEDY := "greedy"


## Generator check (8b): `shots` direct shots at every keystone (centre, then other points of its
## camera-facing faces). {keystone_id: [cleared share per shot]}.
static func keystone_clears(level: Dictionary, host: Node, shots: int, rng: RandomNumberGenerator) -> Dictionary:
	var bodies := SupportCheck._bodies(level)
	var cam := KeystoneCheck.camera_position(level)
	var trials: Array[Dictionary] = []
	for k in level.get("keystones", []):
		var idx := KeystoneCheck._index_of(bodies, str(k))
		if idx < 0:
			continue
		var pts := KeystoneCheck._face_samples(bodies[idx], cam)
		for s in shots:
			var target: Vector3 = SupportCheck._mean(pts) if s == 0 else pts[rng.randi_range(0, pts.size() - 1)]
			trials.append({"kind": KIND_KEYSTONE, "keystone": str(k), "targets": [target]})
	await _run_trials(level, trials, host, maxi(1, mini(trials.size(), int(GameConfig.rule("generator.sim_batch")))))
	var out := {}
	for t in trials:
		if not out.has(t["keystone"]):
			out[t["keystone"]] = []
		(out[t["keystone"]] as Array).append(float(t["ratio"]))
	return out


## Generator check (8b): share of `n` greedy multi-shot runs that solve within level.shots.
static func within_shots_rate(level: Dictionary, host: Node, n: int, rng: RandomNumberGenerator, batch: int = 20) -> float:
	var visible := visible_targets(level)
	var trials: Array[Dictionary] = []
	for i in n:
		trials.append({"kind": KIND_GREEDY, "targets": [_pick(visible, rng)]})
	await _run_trials(level, trials, host, batch)
	var ok := 0
	for t in trials:
		if t["solved"]:
			ok += 1
	return float(ok) / maxf(1, n)


## Full report for an expanded level. opts: samples, batch, greedy_samples, seed.
static func run(level: Dictionary, host: Node, opts: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_msec()
	var targets_cfg: Dictionary = GameConfig.difficulty().get("sim_targets", {})
	var samples := int(opts.get("samples", targets_cfg.get("samples", 200)))
	var greedy_n := int(opts.get("greedy_samples", samples))
	var batch := int(opts.get("batch", 20))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	var visible := visible_targets(level)

	var random_trials: Array[Dictionary] = []
	for i in samples:
		random_trials.append({"kind": KIND_RANDOM, "targets": [_pick(visible, rng)]})
	var key_trials: Array[Dictionary] = []
	var bodies := SupportCheck._bodies(level)
	for k in level.get("keystones", []):
		var idx := KeystoneCheck._index_of(bodies, str(k))
		if idx >= 0:
			var pts := KeystoneCheck._face_samples(bodies[idx], KeystoneCheck.camera_position(level))
			key_trials.append({"kind": KIND_KEYSTONE, "keystone": str(k), "targets": [SupportCheck._mean(pts)]})
	var greedy_trials: Array[Dictionary] = []
	for i in greedy_n:
		greedy_trials.append({"kind": KIND_GREEDY, "targets": [_pick(visible, rng)]})

	var all: Array[Dictionary] = []
	all.append_array(random_trials)
	all.append_array(key_trials)
	all.append_array(greedy_trials)
	await _run_trials(level, all, host, batch)

	var solved := 0
	var jackpots := 0
	var collapse := 0.0
	for t in random_trials:
		collapse += float(t["ratio"])
		if t["solved"]:
			solved += 1
			if t["jackpot"]:
				jackpots += 1
	var keys := {}
	for t in key_trials:
		keys[t["keystone"]] = {"solved": t["solved"], "collapse": t["ratio"], "jackpot": t["jackpot"]}
	var greedy_ok := 0
	for t in greedy_trials:
		if t["solved"]:
			greedy_ok += 1
	var report := {
		"id": level.get("id", ""), "role": str(level.get("role", DifficultyCalc.role_for(int(level.get("index", 1))))),
		"samples": samples, "one_shot_solve_rate": float(solved) / maxf(1, samples),
		"jackpot_rate": float(jackpots) / maxf(1, solved) if solved > 0 else 0.0,
		"collapse_ratio_mean": collapse / maxf(1, samples),
		"keystones": keys, "greedy_samples": greedy_n,
		"within_shots_rate": float(greedy_ok) / maxf(1, greedy_n),
		"visible_targets": visible.size(),
		"seconds": (Time.get_ticks_msec() - started) / 1000.0,
	}
	report["verdict"] = compare(report)
	return report


## Each metric against difficulty.sim_targets: {metric: {value, target, ok}}. Report only.
static func compare(report: Dictionary) -> Dictionary:
	var t: Dictionary = GameConfig.difficulty().get("sim_targets", {})
	var out := {}
	var ranges: Dictionary = t.get("one_shot_solve_rate", {})
	if ranges.has(report["role"]):
		var r: Array = ranges[report["role"]]
		var v := float(report["one_shot_solve_rate"])
		out["one_shot_solve_rate"] = {"value": v, "target": r, "ok": v >= float(r[0]) and v <= float(r[1])}
	var w := float(report["within_shots_rate"])
	out["within_shots_rate"] = {"value": w, "target": [float(t.get("min_solve_rate_within_shots", 0.0)), 1.0],
			"ok": w >= float(t.get("min_solve_rate_within_shots", 0.0))}
	var best_collapse := 0.0
	var any_key := false
	for k: String in report["keystones"]:
		best_collapse = maxf(best_collapse, float(report["keystones"][k]["collapse"]))
		any_key = any_key or bool(report["keystones"][k]["solved"])
	out["keystone_collapse"] = {"value": best_collapse, "target": [float(t.get("min_collapse_ratio", 0.0)), 1.0],
			"ok": best_collapse >= float(t.get("min_collapse_ratio", 0.0))}
	if bool(t.get("require_keystone_success", false)):
		out["keystone_success"] = {"value": any_key, "target": true, "ok": any_key}
	return out


## Points on block faces that the default camera sees (not hidden by another body).
static func visible_targets(level: Dictionary) -> PackedVector3Array:
	var bodies := SupportCheck._bodies(level)
	var cam := KeystoneCheck.camera_position(level)
	var out := PackedVector3Array()
	var n_blocks := (level.get("blocks", []) as Array).size()
	for i in n_blocks:
		for p in KeystoneCheck._face_samples(bodies[i], cam):
			if KeystoneCheck._in_view(level, cam, p) and not KeystoneCheck._blocked(cam, p, bodies, i, 0.0):
				out.append(p)
	return out


static func _pick(points: PackedVector3Array, rng: RandomNumberGenerator) -> Vector3:
	return points[rng.randi_range(0, points.size() - 1)] if not points.is_empty() else Vector3.ZERO


# --- Running trials in parallel copies ---

static func _run_trials(level: Dictionary, trials: Array[Dictionary], host: Node, batch: int) -> void:
	# No Engine.time_scale tricks: in Godot 4 it also scales the physics step (wrong physics).
	# For speed run headless with --fixed-fps 60 (one physics step per frame, CPU speed).
	var i := 0
	while i < trials.size():
		var group := trials.slice(i, mini(i + batch, trials.size()))
		var state := {"left": group.size()}
		# Every batch in a fresh physics world: results do not depend on earlier simulations.
		var world := SupportCheck.isolated_world(host)
		for c in group.size():
			_trial(level, group[c], world, Vector3(c * COPY_SPACING, 0, 0), state)
		while int(state["left"]) > 0:
			await host.get_tree().physics_frame
		world.queue_free()
		# Let the old physics world go before the next one starts (too many live Jolt spaces at
		# once overflowed Jolt's job queue).
		await host.get_tree().process_frame
		i += batch


## One trial in its own copy at `offset`. Fills trial: solved, ratio, jackpot, shots_used.
static func _trial(level: Dictionary, trial: Dictionary, host: Node, offset: Vector3, state: Dictionary) -> void:
	var tree := host.get_tree()
	var holder := Node3D.new()
	holder.position = offset
	var plat := Platform.new()
	var tower := TowerBuilder.new()
	tower.silent = true
	holder.add_child(plat)
	holder.add_child(tower)
	host.add_child(holder)
	var p: Dictionary = level.get("platform", {})
	plat.build(float(p.get("width")), float(p.get("depth")))
	tower.build(level)
	for f in RELEASE_FRAMES:
		await tree.physics_frame

	var target_ratio := float((level.get("objective", {}) as Dictionary).get("target",
			GameConfig.rule("objective_defaults.clear_percent_target")))
	var shots := 1 if str(trial["kind"]) != KIND_GREEDY else int(level.get("shots", GameConfig.rule("shots.default_per_level")))
	var cooldown := float(GameConfig.rule("shots.refire_cooldown_sec"))
	var settle_timeout := float(GameConfig.rule("physics.settle_timeout_sec"))
	var settle_v := float(GameConfig.rule("physics.settle_linear_velocity_threshold"))
	var dt := 1.0 / Engine.physics_ticks_per_second
	var solved := false
	var used := 0
	var balls: Array[Ball] = []
	for s in shots:
		var target: Vector3 = trial["targets"][0] if s == 0 else _greedy_target(tower, offset)
		var ball := _fire(holder, offset, target)
		balls.append(ball)
		used = s + 1
		# Wait for the first contact (or expiry), then the refire cooldown; check the win meanwhile.
		var waited := 0.0
		while is_instance_valid(ball) and ball.get_contact_count() == 0 and waited < settle_timeout:
			await tree.physics_frame
			waited += dt
			if _ratio(tower, offset, level) >= target_ratio:
				solved = true
				break
		if solved:
			break
		var cd := 0.0
		while cd < cooldown:
			await tree.physics_frame
			cd += dt
			if _ratio(tower, offset, level) >= target_ratio:
				solved = true
				break
		if solved:
			break
	# Settle: until everything rests or the timeout (the win is checked every tick, K-023).
	var t := 0.0
	while t < settle_timeout:
		await tree.physics_frame
		t += dt
		if _ratio(tower, offset, level) >= target_ratio:
			solved = true
		if _resting(tower, balls, settle_v):
			break
	trial["solved"] = solved
	trial["ratio"] = _ratio(tower, offset, level)
	trial["jackpot"] = _core_fallen(tower, offset, level)
	trial["remaining"] = _remaining(tower, offset, level)
	trial["broken"] = tower.blocks.filter(func(b: Block) -> bool: return b.is_broken).map(func(b: Block) -> String: return b.block_id)
	trial["shots_used"] = used
	for b in balls:
		if is_instance_valid(b):
			b.queue_free()
	holder.queue_free()
	state["left"] = int(state["left"]) - 1


static func _fire(holder: Node3D, offset: Vector3, target_local: Vector3) -> Ball:
	var cannon := KeystoneCheck._cannon_geometry()
	var def := GameConfig.ball(GameConfig.starting_ball_id())
	var speed := float(def["launch_speed"])
	var g := float(GameConfig.rule("physics.gravity"))
	var arc := str(GameConfig.rule("aim.arc"))
	var muzzle := KeystoneCheck._muzzle(cannon, target_local - (cannon["pivot"] as Vector3))
	var v: Vector3 = Ballistics.solve(muzzle, target_local, speed, g, arc)["velocity"]
	muzzle = KeystoneCheck._muzzle(cannon, v)
	v = Ballistics.solve(muzzle, target_local, speed, g, arc)["velocity"]
	var ball: Ball = BALL_SCENE.instantiate()
	ball.silent = true
	ball.setup(GameConfig.starting_ball_id())
	holder.add_child(ball)
	ball.global_position = muzzle + offset
	ball.launch(v)
	return ball


## Greedy aim: centre of the biggest block still standing on the platform (copy-local).
static func _greedy_target(tower: TowerBuilder, offset: Vector3) -> Vector3:
	var best: Block = null
	for b in tower.blocks:
		if b.is_broken or b.is_fallen or not b.visible:
			continue
		if best == null or b.volume > best.volume:
			best = b
	if best == null:
		return Vector3.ZERO
	return best.world_center_of_mass() - offset


## Cleared share (volume or count, rules.objective_defaults) with the edge rule in copy space.
static func _ratio(tower: TowerBuilder, offset: Vector3, level: Dictionary) -> float:
	var p: Dictionary = level.get("platform", {})
	var hw := float(p.get("width")) / 2.0
	var hd := float(p.get("depth")) / 2.0
	var margin := float(GameConfig.rule("physics.edge_margin"))
	var kill := float(GameConfig.rule("physics.fall_kill_y"))
	var by_volume := str(GameConfig.rule("objective_defaults.clear_measure")) == "volume"
	var broken_counts := bool(GameConfig.rule("objective_defaults.broken_counts_as_cleared"))
	var total := 0.0
	var cleared := 0.0
	for b in tower.blocks:
		var w := b.volume if by_volume else 1.0
		total += w
		var gone := b.is_broken and broken_counts
		if not gone and not b.is_broken:
			gone = EdgeRule.is_fallen(b.world_center_of_mass() - offset, hw, hd, margin, kill)
		if gone:
			cleared += w
	return cleared / total if total > 0.0 else 0.0


## Blocks still on the platform (not broken, not fallen): [{id, shape, mat, volume}] — for reports.
static func _remaining(tower: TowerBuilder, offset: Vector3, level: Dictionary) -> Array:
	var p: Dictionary = level.get("platform", {})
	var out: Array = []
	for b in tower.blocks:
		if b.is_broken:
			continue
		if not EdgeRule.is_fallen(b.world_center_of_mass() - offset, float(p.get("width")) / 2.0, float(p.get("depth")) / 2.0,
				float(GameConfig.rule("physics.edge_margin")), float(GameConfig.rule("physics.fall_kill_y"))):
			out.append({"id": b.block_id, "shape": b.shape_id, "mat": b.material_id, "volume": snappedf(b.volume, 0.01)})
	return out


static func _core_fallen(tower: TowerBuilder, offset: Vector3, level: Dictionary) -> bool:
	var p: Dictionary = level.get("platform", {})
	for c in tower.cores:
		if EdgeRule.is_fallen(c.world_center_of_mass() - offset, float(p.get("width")) / 2.0, float(p.get("depth")) / 2.0,
				float(GameConfig.rule("physics.edge_margin")), float(GameConfig.rule("physics.fall_kill_y"))):
			return true
	return false


static func _resting(tower: TowerBuilder, balls: Array[Ball], v: float) -> bool:
	for b in balls:
		if is_instance_valid(b):
			return false
	for b in tower.all_bodies():
		if b.visible and not b.sleeping and b.linear_velocity.length() > v:
			return false
	return true
