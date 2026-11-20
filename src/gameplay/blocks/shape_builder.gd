@tool
class_name ShapeBuilder
extends RefCounted
## Builds CollisionShape3D children (+ grey-box MeshInstance3D) for one shapes.json entry and
## returns the total collider volume in m^3 (mass = volume x material density, docs/02 §6.2).
## Dynamic bodies only use box / sphere / cylinder / convex compounds — never concave/trimesh.

const HULL_EPSILON := 1e-5
## A chamfer never takes more than this share of the box's smallest side.
const BEVEL_MAX_SHARE := 0.25


## bevel > 0: box colliders get a chamfered mesh (Faz 7, rules.visuals.block_bevel); the collider
## itself stays an exact box, so physics never changes.
static func build(body: CollisionObject3D, shape_def: Dictionary, visual_mat: Material, bevel: float = 0.0) -> float:
	var volume := 0.0
	for c: Dictionary in shape_def.get("colliders", []):
		var col := CollisionShape3D.new()
		var mesh: Mesh = null
		var xform := Transform3D.IDENTITY
		match str(c.get("type")):
			"box":
				var size := to_vec3(c["size"])
				var box := BoxShape3D.new()
				box.size = size
				col.shape = box
				if bevel > 0.0:
					mesh = bevel_box_mesh(size, bevel)
				else:
					var bm := BoxMesh.new()
					bm.size = size
					mesh = bm
				xform.origin = to_vec3(c["pos"])
				volume += size.x * size.y * size.z
			"sphere":
				var r := float(c["radius"])
				var sp := SphereShape3D.new()
				sp.radius = r
				col.shape = sp
				var sm := SphereMesh.new()
				sm.radius = r
				sm.height = 2.0 * r
				mesh = sm
				xform.origin = to_vec3(c["pos"])
				volume += 4.0 / 3.0 * PI * r * r * r
			"cylinder":
				var r := float(c["radius"])
				var h := float(c["height"])
				var cy := CylinderShape3D.new()
				cy.radius = r
				cy.height = h
				col.shape = cy
				var cm := CylinderMesh.new()
				cm.top_radius = r
				cm.bottom_radius = r
				cm.height = h
				mesh = cm
				xform = Transform3D(_axis_basis(str(c.get("axis", "y"))), to_vec3(c["pos"]))
				volume += PI * r * r * h
			"convex":
				var pts := PackedVector3Array()
				for p: Array in c["points"]:
					pts.append(to_vec3(p))
				var cv := ConvexPolygonShape3D.new()
				cv.points = pts
				col.shape = cv
				var faces := hull_faces(pts)
				mesh = _faces_to_mesh(faces)
				volume += hull_volume(pts, faces)
			_:
				push_error("ShapeBuilder: bilinmeyen collider tipi: %s" % c.get("type"))
				continue
		col.transform = xform
		body.add_child(col)
		if visual_mat and mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.transform = xform
			mi.material_override = visual_mat
			body.add_child(mi)
	return volume


static func to_vec3(v: Variant) -> Vector3:
	var arr: Array = v
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


## Cylinder meshes/shapes run along Y; rotate them for "x" / "z" axis colliders.
static func _axis_basis(axis: String) -> Basis:
	match axis:
		"x":
			return Basis(Vector3.BACK, PI / 2.0)
		"z":
			return Basis(Vector3.RIGHT, PI / 2.0)
	return Basis.IDENTITY


static var _bevel_cache: Dictionary = {}


## Box of `size` with every edge chamfered at 45° by `bevel` (capped at BEVEL_MAX_SHARE of the
## smallest side): the convex hull of three boxes, each full along one axis and shrunk by the bevel
## on the other two. Cached per size.
static func bevel_box_mesh(size: Vector3, bevel: float) -> Mesh:
	var b := minf(bevel, BEVEL_MAX_SHARE * minf(size.x, minf(size.y, size.z)))
	var key := "%.4f|%.4f|%.4f|%.4f" % [size.x, size.y, size.z, b]
	if _bevel_cache.has(key):
		return _bevel_cache[key]
	var h := size / 2.0
	var pts := PackedVector3Array()
	for axis in 3:
		var e := Vector3(h.x - b, h.y - b, h.z - b)
		e[axis] = h[axis]
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					pts.append(Vector3(e.x * sx, e.y * sy, e.z * sz))
	var mesh := _faces_to_mesh(hull_faces(pts))
	_bevel_cache[key] = mesh
	return mesh


## Faces of the convex hull of a small point set, each an ordered polygon (CCW seen from outside).
## Brute force over point triples — fine for the handful of points a block collider has.
static func hull_faces(pts: PackedVector3Array) -> Array[PackedVector3Array]:
	var center := _centroid(pts)
	var planes: Array[Plane] = []
	var faces: Array[PackedVector3Array] = []
	var n := pts.size()
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				var normal := (pts[j] - pts[i]).cross(pts[k] - pts[i])
				if normal.length_squared() < HULL_EPSILON:
					continue
				var plane := Plane(normal.normalized(), pts[i])
				if plane.is_point_over(center):
					plane = -plane
				var is_face := true
				for p in pts:
					if plane.distance_to(p) > HULL_EPSILON:
						is_face = false
						break
				if not is_face or _has_plane(planes, plane):
					continue
				planes.append(plane)
				var on_plane := PackedVector3Array()
				for p in pts:
					if absf(plane.distance_to(p)) <= HULL_EPSILON:
						on_plane.append(p)
				faces.append(_sort_around(on_plane, plane.normal))
	return faces


static func hull_volume(pts: PackedVector3Array, faces: Array[PackedVector3Array]) -> float:
	var center := _centroid(pts)
	var volume := 0.0
	for f in faces:
		var area_vec := Vector3.ZERO
		for i in range(1, f.size() - 1):
			area_vec += (f[i] - f[0]).cross(f[i + 1] - f[0])
		var area := area_vec.length() / 2.0
		var normal := area_vec.normalized()
		var height := absf(normal.dot(f[0] - center))
		volume += area * height / 3.0
	return volume


static func _faces_to_mesh(faces: Array[PackedVector3Array]) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var normal := (f[1] - f[0]).cross(f[2] - f[0]).normalized()
		# Godot front faces are clockwise, polygons are CCW from outside -> emit reversed fans.
		for i in range(1, f.size() - 1):
			for p in [f[0], f[i + 1], f[i]]:
				st.set_normal(normal)
				st.add_vertex(p)
	return st.commit()


static func _centroid(pts: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / float(pts.size())


static func _has_plane(planes: Array[Plane], plane: Plane) -> bool:
	for q in planes:
		if q.normal.is_equal_approx(plane.normal) and absf(q.d - plane.d) < HULL_EPSILON:
			return true
	return false


static func _sort_around(points: PackedVector3Array, normal: Vector3) -> PackedVector3Array:
	var c := _centroid(points)
	var u := (points[0] - c).normalized()
	var v := normal.cross(u)
	var items: Array = []
	for p in points:
		items.append([atan2((p - c).dot(v), (p - c).dot(u)), p])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := PackedVector3Array()
	for it: Array in items:
		out.append(it[1])
	return out
