class_name KeystoneCheck
extends RefCounted
## docs/03 §4 rule 3 (S-007): every keystone must be
##  1. visible from the fixed default camera (rules.camera + level camera_override): sample points
##     on its camera-facing faces, inside the view frustum, not hidden behind another body;
##     visible ratio >= rules.level_checks.keystone_min_visible_ratio;
##  2. reachable from the cannon: the ball's path (ball radius, gravity, launch_speed) hits the
##     keystone before anything else, either with the tap_target arc (rules.aim.arc) or with a
##     drag_release shot (pitch up to rules.aim.drag_pitch_max_deg = the "lob").
## Pure maths on the expanded level (no scene): rays / ball path against convex collider pieces.

const CANNON_SCENE := preload("res://src/gameplay/cannon/cannon.tscn")
## drag_release pitch sweep step (degrees) when looking for a lob.
const LOB_PITCH_STEP_DEG := 2.5
## Tiny offset so a face sample is not "hidden" by its own face.
const SURFACE_OFFSET := 0.001
const VIA_ARC := "tap_target"
const VIA_DRAG := "drag_release"


## {ok, issues: [String], keystones: {id: {visible_ratio, reachable, via}}}
static func check(level: Dictionary) -> Dictionary:
	var bodies := SupportCheck._bodies(level)
	var plat := _platform_box(level)
	var issues: PackedStringArray = []
	var report := {}
	var min_ratio := float(GameConfig.rule("level_checks.keystone_min_visible_ratio"))
	for k in level.get("keystones", []):
		var index := _index_of(bodies, str(k))
		if index < 0:
			issues.append("keystone %s yok" % k)
			continue
		var ratio := visible_ratio(level, bodies, index)
		var reach := reachable(bodies, plat, index)
		report[str(k)] = {"visible_ratio": ratio, "reachable": reach["ok"], "via": reach["via"]}
		if ratio < min_ratio:
			issues.append("keystone %s kameradan yeterince görünmüyor (%%%d < %%%d)" % [k, roundi(ratio * 100), roundi(min_ratio * 100)])
		if not reach["ok"]:
			issues.append("keystone %s toptan vurulamıyor" % k)
	return {"ok": issues.is_empty(), "issues": issues, "keystones": report}


# --- Visibility ---

static func camera_position(level: Dictionary) -> Vector3:
	var cfg := _camera_cfg(level)
	var target := Vector3(0.0, float(cfg["look_at_height"]), 0.0)
	var pitch := deg_to_rad(float(cfg["pitch_deg"]))
	var yaw := deg_to_rad(float(cfg["yaw_deg"]))
	return target + (Vector3(0.0, sin(pitch), cos(pitch)) * float(cfg["distance"])).rotated(Vector3.UP, yaw)


static func visible_ratio(level: Dictionary, bodies: Array[Dictionary], index: int) -> float:
	var cam := camera_position(level)
	var samples := _face_samples(bodies[index], cam)
	if samples.is_empty():
		return 0.0
	var seen := 0
	for p in samples:
		if _in_view(level, cam, p) and not _blocked(cam, p, bodies, index, 0.0):
			seen += 1
	return float(seen) / samples.size()


static func _in_view(level: Dictionary, cam: Vector3, p: Vector3) -> bool:
	var cfg := _camera_cfg(level)
	var target := Vector3(0.0, float(cfg["look_at_height"]), 0.0)
	var f := (target - cam).normalized()
	var right := f.cross(Vector3.UP).normalized()
	var up := right.cross(f)
	var d := p - cam
	var depth := d.dot(f)
	if depth <= 0.0:
		return false
	var w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var half := deg_to_rad(float(cfg["fov_deg"])) / 2.0
	var half_h: float
	var half_v: float
	if str(cfg["keep_aspect"]) == "width":
		half_h = half
		half_v = atan(tan(half) * h / w)
	else:
		half_v = half
		half_h = atan(tan(half) * w / h)
	return absf(atan2(d.dot(right), depth)) <= half_h and absf(atan2(d.dot(up), depth)) <= half_v


## Sample points (face_samples^2 per face) on the faces of a body that face `eye`.
static func _face_samples(body: Dictionary, eye: Vector3) -> PackedVector3Array:
	var n_s := int(GameConfig.rule("level_checks.face_samples"))
	var out := PackedVector3Array()
	for piece: Dictionary in body["pieces"]:
		if bool(piece["sphere"]):
			out.append(piece["center"])
			continue
		for f: Dictionary in piece["faces"]:
			var pts: PackedVector3Array = f["pts"]
			var n: Vector3 = f["n"]
			var c := SupportCheck._mean(pts)
			if n.dot(eye - c) <= 0.0:
				continue
			for i in n_s:
				for j in n_s:
					# Points spread over the face: blend the centre towards pairs of corners.
					var u := (i + 0.5) / n_s
					var v := (j + 0.5) / n_s
					var a := pts[0].lerp(pts[1], u)
					var b := pts[pts.size() - 1].lerp(pts[2 % pts.size()], u)
					out.append(a.lerp(b, v) + n * SURFACE_OFFSET)
	return out


## True if the segment from -> to (inflated by radius) hits a body other than `skip` first.
static func _blocked(from: Vector3, to: Vector3, bodies: Array[Dictionary], skip: int, radius: float) -> bool:
	for i in bodies.size():
		if i == skip:
			continue
		for piece: Dictionary in bodies[i]["pieces"]:
			var t := _segment_hit(from, to, piece, radius)
			if t >= 0.0 and t < 1.0:
				return true
	return false


# --- Reachability ---

## {ok, via}: the ball reaches the keystone first with the tap_target arc or a drag_release shot.
static func reachable(bodies: Array[Dictionary], plat: Dictionary, index: int) -> Dictionary:
	var cannon := _cannon_geometry()
	var ball := GameConfig.ball(GameConfig.starting_ball_id())
	var speed := float(ball["launch_speed"])
	var radius := float(ball["radius"])
	var g := float(GameConfig.rule("physics.gravity"))
	var arc := str(GameConfig.rule("aim.arc"))
	for p in _face_samples(bodies[index], cannon["pivot"]):
		var muzzle := _muzzle(cannon, p - (cannon["pivot"] as Vector3))
		var v: Vector3 = Ballistics.solve(muzzle, p, speed, g, arc)["velocity"]
		muzzle = _muzzle(cannon, v)
		v = Ballistics.solve(muzzle, p, speed, g, arc)["velocity"]
		if _first_hit(muzzle, v, g, radius, bodies, plat) == index:
			return {"ok": true, "via": VIA_ARC}
	# Lob: drag_release angles (yaw towards the keystone, pitch swept up to the limit).
	var centre: Vector3 = bodies[index]["com"]
	var to := centre - (cannon["pivot"] as Vector3)
	var yaw := rad_to_deg(atan2(to.x, -to.z))
	if absf(yaw) <= float(GameConfig.rule("aim.drag_yaw_max_deg")):
		var pitch := float(GameConfig.rule("aim.drag_pitch_min_deg"))
		var pitch_max := float(GameConfig.rule("aim.drag_pitch_max_deg"))
		while pitch <= pitch_max:
			var v := Ballistics.velocity_from_angles(yaw, pitch, speed)
			if _first_hit(_muzzle(cannon, v), v, g, radius, bodies, plat) == index:
				return {"ok": true, "via": VIA_DRAG}
			pitch += LOB_PITCH_STEP_DEG
	return {"ok": false, "via": ""}


## Index of the first body the ball touches (-1 = platform / nothing).
static func _first_hit(from: Vector3, v: Vector3, g: float, radius: float, bodies: Array[Dictionary], plat: Dictionary) -> int:
	var dt := 1.0 / float(GameConfig.rule("physics.tick_rate"))
	var max_t := float(GameConfig.rule("physics.settle_timeout_sec"))
	var kill_y := float(GameConfig.rule("physics.fall_kill_y"))
	var t := 0.0
	var p := from
	while t < max_t and p.y > kill_y:
		t += dt
		var q := Ballistics.point_at(from, v, g, t)
		var best := INF
		var hit := -2
		for i in bodies.size():
			for piece: Dictionary in bodies[i]["pieces"]:
				var s := _segment_hit(p, q, piece, radius)
				if s >= 0.0 and s <= 1.0 and s < best:
					best = s
					hit = i
		var sp := _segment_hit(p, q, plat, radius)
		if sp >= 0.0 and sp <= 1.0 and sp < best:
			return -1
		if hit != -2:
			return hit
		p = q
	return -1


# --- Geometry ---

## Entry parameter (0..1) of segment a->b into a convex piece grown by `radius`, or -1.
static func _segment_hit(a: Vector3, b: Vector3, piece: Dictionary, radius: float) -> float:
	var d := b - a
	if bool(piece["sphere"]):
		var c: Vector3 = piece["center"]
		var r: float = (c - (piece["verts"] as PackedVector3Array)[0]).length() + radius
		var m := a - c
		var qa := d.dot(d)
		var qb := 2.0 * m.dot(d)
		var qc := m.dot(m) - r * r
		if qc <= 0.0:
			return 0.0
		var disc := qb * qb - 4.0 * qa * qc
		if disc < 0.0 or qa == 0.0:
			return -1.0
		var t := (-qb - sqrt(disc)) / (2.0 * qa)
		return t if t >= 0.0 and t <= 1.0 else -1.0
	var t_in := 0.0
	var t_out := 1.0
	for f: Dictionary in piece["faces"]:
		var n: Vector3 = f["n"]
		var plane_d := n.dot((f["pts"] as PackedVector3Array)[0]) + radius
		var denom := n.dot(d)
		var num := plane_d - n.dot(a)
		if is_zero_approx(denom):
			if num < 0.0:
				return -1.0
			continue
		var t := num / denom
		if denom < 0.0:
			t_in = maxf(t_in, t)
		else:
			t_out = minf(t_out, t)
		if t_in > t_out:
			return -1.0
	return t_in


static func _platform_box(level: Dictionary) -> Dictionary:
	var plat: Dictionary = level.get("platform", {})
	var thick := float(GameConfig.rule("platform.thickness"))
	return SupportCheck._piece({"type": "box", "pos": [0, -thick / 2.0, 0],
			"size": [float(plat.get("width", 0)), thick, float(plat.get("depth", 0))]}, Transform3D.IDENTITY)


## Cannon pivot (world) and muzzle length, read from cannon.tscn + rules.cannon.position / scale.
static func _cannon_geometry() -> Dictionary:
	var c: Node3D = CANNON_SCENE.instantiate()
	var s := float(GameConfig.rule("cannon.scale"))
	var pivot_local := (c.get_node("Yaw/Pitch") as Node3D).position * s
	var muzzle_len := absf((c.get_node("Yaw/Pitch/Muzzle") as Node3D).position.z) * s
	c.free()
	return {"pivot": ShapeBuilder.to_vec3(GameConfig.rule("cannon.position")) + pivot_local, "muzzle_len": muzzle_len}


static func _muzzle(cannon: Dictionary, dir: Vector3) -> Vector3:
	return (cannon["pivot"] as Vector3) + dir.normalized() * float(cannon["muzzle_len"])


static func _camera_cfg(level: Dictionary) -> Dictionary:
	var cfg: Dictionary = (GameConfig.rule("camera") as Dictionary).duplicate()
	var override: Variant = level.get("camera_override")
	if override is Dictionary:
		cfg.merge(override, true)
	return cfg


static func _index_of(bodies: Array[Dictionary], id: String) -> int:
	for i in bodies.size():
		if str(bodies[i]["id"]) == id:
			return i
	return -1
