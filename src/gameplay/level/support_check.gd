class_name SupportCheck
extends RefCounted
## Static balance check of a tower (docs/03 §4 rule 1), then a short physics confirmation.
##
## Static part, check(level) (pure maths, no scene needed):
##  a. Every collider piece of every body is turned into world-space vertices and faces
##     (block rotation = Euler YXZ, like Block.rotation_degrees). Cylinders become prisms.
##  b. Contacts "A rests on B": each downward-facing face of A is clipped to the thin slab
##     (physics.support_contact_epsilon) around each upward-facing face of B and to that face's
##     outline. Flat-on-flat gives the overlap polygon; tilted blocks give the corner / edge lines
##     they touch with. The platform top (y = 0) is a support too.
##  c. For each block X: the load group U = X + everything that (transitively) rests on X.
##     Support polygon = convex hull (xz) of all contacts between U and the bodies outside U.
##     The combined centre of mass of U (mass = volume x density) must lie inside that polygon,
##     at least physics.support_margin from its edge. No contact = "desteksiz".
##     A plank on two pillars therefore passes: the pillar's group (pillar + plank) is also held by
##     the other pillar.
##  Spheres (Golden Core) are load only: their own balance is left to the physics check.
##
## Physics part, physics_drift(level, parent): builds the tower awake (not asleep), runs
## physics.pre_settle_sec and reports how far each body moved; > physics.max_settle_drift = fail.

const PLATFORM := -1
## Geometry tolerances of the algorithm (not game rules):
## A face can carry weight when normal.y >= this (steeper faces only push sideways).
const SUPPORT_NORMAL_MIN_Y := 0.05
## Polygons thinner than this (m^2) are a line or a point.
const MIN_POLYGON_AREA := 1e-4
const CYLINDER_SEGMENTS := 12

const REASON_UNSUPPORTED := "desteksiz"
const REASON_LINE := "destek tek nokta/çizgi"
const REASON_OUTSIDE := "ağırlık merkezi destek alanının dışında"
const REASON_MARGIN := "ağırlık merkezi destek kenarına çok yakın"


## Result: {ok: bool, issues: [{id, reason, margin}], margins: {id: float}}
## margin = signed distance (m) of the group's centre of mass to the support polygon edge
## (negative = outside).
static func check(level: Dictionary) -> Dictionary:
	var eps := float(GameConfig.rule("physics.support_contact_epsilon"))
	var margin_min := float(GameConfig.rule("physics.support_margin"))
	var bodies := _bodies(level)
	var plat := _platform_piece(level)

	# contacts[a][b] = PackedVector2Array of xz points where body a rests on body b (b = PLATFORM ok)
	var contacts: Array[Dictionary] = []
	for i in bodies.size():
		contacts.append({})
	for i in bodies.size():
		for pa: Dictionary in bodies[i]["pieces"]:
			var pts := _contacts(pa, plat, eps)
			if not pts.is_empty():
				_add(contacts[i], PLATFORM, pts)
			for j in bodies.size():
				if j == i:
					continue
				for pb: Dictionary in bodies[j]["pieces"]:
					pts = _contacts(pa, pb, eps)
					if not pts.is_empty():
						_add(contacts[i], j, pts)

	var issues: Array[Dictionary] = []
	var margins := {}
	for x in bodies.size():
		if not bodies[x]["checked"]:
			continue
		var group := _load_group(x, contacts)
		var support := PackedVector2Array()
		var mass := 0.0
		var com := Vector3.ZERO
		for u: int in group:
			mass += float(bodies[u]["mass"])
			com += (bodies[u]["com"] as Vector3) * float(bodies[u]["mass"])
			for other: int in contacts[u]:
				if not group.has(other):
					support.append_array(contacts[u][other])
		com /= maxf(mass, 1e-9)
		var id := str(bodies[x]["id"])
		var m := _margin(Vector2(com.x, com.z), support)
		margins[id] = m
		var reason := ""
		if support.is_empty():
			reason = REASON_UNSUPPORTED
		elif is_nan(m):
			reason = REASON_LINE
		elif m < 0.0:
			reason = REASON_OUTSIDE
		elif m < margin_min:
			reason = REASON_MARGIN
		if not reason.is_empty():
			issues.append({"id": id, "reason": reason, "margin": 0.0 if is_nan(m) else m})
	return {"ok": issues.is_empty(), "issues": issues, "margins": margins}


## Human-readable one-line summary for logs / the editor.
static func describe(result: Dictionary) -> String:
	if result["ok"]:
		return "denge OK (%d blok)" % (result["margins"] as Dictionary).size()
	var parts: PackedStringArray = []
	for i: Dictionary in result["issues"]:
		parts.append("%s: %s (%.3f)" % [i["id"], i["reason"], i["margin"]])
	return "denge HATA: " + "; ".join(parts)


# --- Physics confirmation ---

## Builds the level under `parent` with every body awake, simulates physics.pre_settle_sec and
## returns {ok, max_drift, drifts: {id: metres}, worst: id}. The temporary nodes are freed.
static func physics_drift(level: Dictionary, parent: Node) -> Dictionary:
	var world := isolated_world(parent)
	var holder := Node3D.new()
	var platform := Platform.new()
	var tower := TowerBuilder.new()
	tower.silent = true
	holder.add_child(platform)
	holder.add_child(tower)
	world.add_child(holder)
	var plat: Dictionary = level.get("platform", {})
	platform.build(float(plat.get("width")), float(plat.get("depth")))
	tower.build(level)
	var tree := parent.get_tree()
	await tree.physics_frame  # TowerBuilder releases the bodies after one tick
	await tree.physics_frame
	tower.wake_all()
	var ticks := ceili(float(GameConfig.rule("physics.pre_settle_sec")) * Engine.physics_ticks_per_second)
	for t in ticks:
		await tree.physics_frame
	var drifts := {}
	var worst := ""
	var max_drift := 0.0
	for b in tower.all_bodies():
		var d := b.drift()
		drifts[b.block_id] = d
		if d > max_drift:
			max_drift = d
			worst = b.block_id
	world.queue_free()
	await tree.process_frame  # free the physics world before the next check starts
	return {"ok": max_drift <= float(GameConfig.rule("physics.max_settle_drift")),
			"max_drift": max_drift, "drifts": drifts, "worst": worst}


## A fresh physics world for a check / simulation (a SubViewport with its own World3D that renders
## nothing), so the result never depends on other bodies or on what was simulated before
## (Jolt is deterministic for the same world history only). Free it when done.
static func isolated_world(parent: Node) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(2, 2)
	parent.add_child(vp)
	return vp


# --- Bodies and pieces ---

## [{id, checked, mass, com (world), pieces: [{verts, faces: [{n, pts}]}]}] for blocks then cores.
static func _bodies(level: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index := 0
	for bd: Dictionary in level.get("blocks", []):
		index += 1
		out.append(_body(str(bd.get("id", "b%02d" % index)), str(bd["shape"]), str(bd["mat"]), bd))
	var core_shape := str(GameConfig.rule("objective_defaults.core_shape"))
	var core_mat := str(GameConfig.rule("objective_defaults.core_material"))
	index = 0
	for cd: Dictionary in level.get("cores", []):
		index += 1
		out.append(_body("core%d" % index, core_shape, core_mat, cd))
	return out


static func _body(id: String, shape: String, mat: String, d: Dictionary) -> Dictionary:
	var rot := ShapeBuilder.to_vec3(d.get("rot", [0, 0, 0]))
	var xform := Transform3D(Basis.from_euler(rot * (PI / 180.0), EULER_ORDER_YXZ),
			Vector3(float(d["x"]), float(d["y"]), float(d["z"])))
	var density := float(GameConfig.material(mat).get("density", 1.0))
	var pieces: Array[Dictionary] = []
	var volume := 0.0
	var com := Vector3.ZERO
	var checked := false
	for c: Dictionary in GameConfig.shape(shape).get("colliders", []):
		var piece := _piece(c, xform)
		if piece.is_empty():
			continue
		pieces.append(piece)
		volume += float(piece["volume"])
		com += (piece["center"] as Vector3) * float(piece["volume"])
		if not bool(piece["sphere"]):
			checked = true
	com /= maxf(volume, 1e-9)
	return {"id": id, "checked": checked, "mass": volume * density, "com": com, "pieces": pieces}


## World-space piece: {verts, faces [{n, pts}], center, volume, sphere}.
static func _piece(c: Dictionary, xform: Transform3D) -> Dictionary:
	var local := PackedVector3Array()
	var volume := 0.0
	match str(c.get("type")):
		"box":
			var p := ShapeBuilder.to_vec3(c["pos"])
			var h := ShapeBuilder.to_vec3(c["size"]) / 2.0
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						local.append(p + Vector3(h.x * sx, h.y * sy, h.z * sz))
			volume = 8.0 * h.x * h.y * h.z
		"convex":
			for q: Array in c["points"]:
				local.append(ShapeBuilder.to_vec3(q))
		"cylinder":
			var p := ShapeBuilder.to_vec3(c["pos"])
			var r := float(c["radius"])
			var hh := float(c["height"]) / 2.0
			var basis := ShapeBuilder._axis_basis(str(c.get("axis", "y")))
			for i in CYLINDER_SEGMENTS:
				var a := TAU * i / CYLINDER_SEGMENTS
				for sy in [-1.0, 1.0]:
					local.append(p + basis * Vector3(r * cos(a), hh * sy, r * sin(a)))
			volume = PI * r * r * 2.0 * hh
		"sphere":
			var r := float(c["radius"])
			var center := xform * ShapeBuilder.to_vec3(c["pos"])
			return {"verts": PackedVector3Array([center - Vector3(0, r, 0)]), "faces": [],
					"center": center, "volume": 4.0 / 3.0 * PI * r * r * r, "sphere": true,
					"aabb": AABB(center - Vector3(r, r, r), Vector3(2 * r, 2 * r, 2 * r))}
		_:
			return {}
	var world := PackedVector3Array()
	for v in local:
		world.append(xform * v)
	var faces: Array[Dictionary] = []
	for f in ShapeBuilder.hull_faces(world):
		var n := (f[1] - f[0]).cross(f[2] - f[0]).normalized()
		var center := Vector3.ZERO
		for v in world:
			center += v
		center /= world.size()
		if n.dot(f[0] - center) < 0.0:
			n = -n
		faces.append({"n": n, "pts": f})
	if volume == 0.0:
		volume = ShapeBuilder.hull_volume(world, ShapeBuilder.hull_faces(world))
	var c3 := Vector3.ZERO
	for v in world:
		c3 += v
	var box := AABB(world[0], Vector3.ZERO)
	for v in world:
		box = box.expand(v)
	return {"verts": world, "faces": faces, "center": c3 / world.size(), "volume": volume, "sphere": false,
			"aabb": box}


static func _platform_piece(level: Dictionary) -> Dictionary:
	var plat: Dictionary = level.get("platform", {})
	var hw := float(plat.get("width", 0)) / 2.0
	var hd := float(plat.get("depth", 0)) / 2.0
	var top := PackedVector3Array([Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd), Vector3(hw, 0, hd), Vector3(hw, 0, -hd)])
	return {"verts": PackedVector3Array(), "faces": [{"n": Vector3.UP, "pts": top}], "sphere": false,
			"aabb": AABB(Vector3(-hw, 0, -hd), Vector3(2 * hw, 0, 2 * hd))}


# --- Contacts ---

## xz points where piece a rests on piece b.
static func _contacts(a: Dictionary, b: Dictionary, eps: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not (a["aabb"] as AABB).grow(eps).intersects((b["aabb"] as AABB).grow(eps)):
		return out
	# A sphere has no faces: its lowest point resting on an upward face of b.
	if (a["faces"] as Array).is_empty():
		for v: Vector3 in a["verts"]:
			for fb: Dictionary in b["faces"]:
				if (fb["n"] as Vector3).y >= SUPPORT_NORMAL_MIN_Y and _on_face(v, fb, eps):
					out.append(Vector2(v.x, v.z))
		return out
	# Every downward face of a against every upward face of b: the part of fa that lies within eps
	# of fb's plane and inside fb's outline. Covers flat-on-flat (overlap polygon), a corner on a
	# face, and an edge across an edge (tilted plank on a cube corner) alike.
	for fa: Dictionary in a["faces"]:
		if (fa["n"] as Vector3).y > -SUPPORT_NORMAL_MIN_Y:
			continue
		for fb: Dictionary in b["faces"]:
			if (fb["n"] as Vector3).y < SUPPORT_NORMAL_MIN_Y:
				continue
			for p in _touch_region(fa["pts"], fb, eps):
				out.append(Vector2(p.x, p.z))
	return out


## Polygon fa clipped to the slab |n.(x - fb0)| <= eps and to fb's outline (its edge planes).
static func _touch_region(fa: PackedVector3Array, fb: Dictionary, eps: float) -> PackedVector3Array:
	var n: Vector3 = fb["n"]
	var pts: PackedVector3Array = fb["pts"]
	var d := n.dot(pts[0])
	var poly := _clip(fa, n, d + eps)
	poly = _clip(poly, -n, -(d - eps))
	var centre := _mean(pts)
	var count := pts.size()
	for i in count:
		if poly.is_empty():
			break
		var a := pts[i]
		var side := (pts[(i + 1) % count] - a).cross(n).normalized()
		if side.dot(centre - a) > 0.0:
			side = -side  # make it point outwards
		poly = _clip(poly, side, side.dot(a) + eps)
	return poly


## Sutherland–Hodgman: the part of a convex polygon where normal.x <= d.
static func _clip(poly: PackedVector3Array, normal: Vector3, d: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var count := poly.size()
	for i in count:
		var p := poly[i]
		var q := poly[(i + 1) % count]
		var dp := normal.dot(p) - d
		var dq := normal.dot(q) - d
		if dp <= 0.0:
			out.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			out.append(p + (q - p) * (dp / (dp - dq)))
	return out


## True when p lies on the face plane (within eps) and inside its polygon (within eps).
static func _on_face(p: Vector3, f: Dictionary, eps: float) -> bool:
	var n: Vector3 = f["n"]
	var pts: PackedVector3Array = f["pts"]
	if absf(n.dot(p - pts[0])) > eps:
		return false
	var count := pts.size()
	for i in count:
		var a := pts[i]
		var edge := pts[(i + 1) % count] - a
		var inward := n.cross(edge).normalized()
		var side := inward.dot(p - a)
		# Faces may wind either way: test against the polygon's own centre.
		var centre_side := inward.dot(_mean(pts) - a)
		if centre_side < 0.0:
			side = -side
		if side < -eps:
			return false
	return true


static func _mean(pts: PackedVector3Array) -> Vector3:
	var s := Vector3.ZERO
	for p in pts:
		s += p
	return s / pts.size()


static func _add(d: Dictionary, key: int, pts: PackedVector2Array) -> void:
	# Packed arrays are values: read, append, write back.
	var cur: PackedVector2Array = d.get(key, PackedVector2Array())
	cur.append_array(pts)
	d[key] = cur


## x + every body that rests (directly or through others) on x.
static func _load_group(x: int, contacts: Array[Dictionary]) -> Array[int]:
	var group: Array[int] = [x]
	var i := 0
	while i < group.size():
		var below := group[i]
		for a in contacts.size():
			if not group.has(a) and (contacts[a] as Dictionary).has(below):
				group.append(a)
		i += 1
	return group


## Signed distance of p to the convex hull of pts (negative outside); NAN if the hull has no area.
static func _margin(p: Vector2, pts: PackedVector2Array) -> float:
	if pts.is_empty():
		return -INF
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() > 1 and hull[0] == hull[-1]:
		hull.remove_at(hull.size() - 1)
	if hull.size() < 3 or absf(_area(hull)) < MIN_POLYGON_AREA:
		return NAN
	var d := INF
	for i in hull.size():
		var q := Geometry2D.get_closest_point_to_segment(p, hull[i], hull[(i + 1) % hull.size()])
		d = minf(d, p.distance_to(q))
	return d if Geometry2D.is_point_in_polygon(p, hull) else -d


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a / 2.0
