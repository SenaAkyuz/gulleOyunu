@tool
class_name LevelPreview
extends RefCounted
## Editor preview of a level (Step 10, docs/03 §8.2, K-024): every block is a StaticBody3D named
## by its id with the shape's colliders + grey-box mesh (ShapeBuilder), so Godot's own move /
## rotate gizmo edits it; physics never runs in the editor. read() turns the nodes back into
## the level JSON (positions / rotations from the transforms, the rest from node metadata).
## Works without the autoloads (they do not run in the editor): shapes, colours and the platform
## thickness are passed in (`data` = {shapes, rules}), loaded from game_data by the dock.

const ROOT_NAME := "LevelPreview"
const META_BLOCK := "ordino_block"
const META_CORE := "ordino_core"
const META_HEADER := "ordino_level"
const PLATFORM_NAME := "Platform"
const KEYSTONE_COLOR := Color(1.0, 0.25, 0.2)
## Positions / angles written back to JSON are rounded to this.
const SNAP := 0.001


static func build(level: Dictionary, data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = ROOT_NAME
	var header := level.duplicate(true)
	for k in ["blocks", "cores", "keystones", "_expanded", "_expand_warnings"]:
		header.erase(k)
	root.set_meta(META_HEADER, header)
	var shapes: Dictionary = data.get("shapes", {})
	var rules: Dictionary = data.get("rules", {})
	var plat: Dictionary = level.get("platform", {})
	var thick := float((rules.get("platform", {}) as Dictionary).get("thickness", 1.0))
	var pm := MeshInstance3D.new()
	pm.name = PLATFORM_NAME
	var box := BoxMesh.new()
	box.size = Vector3(float(plat.get("width", 4)), thick, float(plat.get("depth", 3)))
	pm.mesh = box
	pm.position.y = -thick / 2.0
	root.add_child(pm)
	var keystones: Array = level.get("keystones", [])
	for b: Dictionary in level.get("blocks", []):
		var body := StaticBody3D.new()
		body.name = str(b["id"])
		var color: Color = Block.PLACEHOLDER_COLORS.get(str(b["mat"]), Block.FALLBACK_COLOR)
		if keystones.has(b["id"]):
			color = color.lerp(KEYSTONE_COLOR, 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		ShapeBuilder.build(body, shapes.get(str(b["shape"]), {}), mat)
		body.position = Vector3(float(b["x"]), float(b["y"]), float(b["z"]))
		body.rotation_degrees = ShapeBuilder.to_vec3(b.get("rot", [0, 0, 0]))
		body.set_meta(META_BLOCK, {"shape": b["shape"], "mat": b["mat"], "role": b.get("role", ""),
				"keystone": keystones.has(b["id"])})
		root.add_child(body)
	var core_shape := str((rules.get("objective_defaults", {}) as Dictionary).get("core_shape", "core_sphere"))
	var i := 0
	for c: Dictionary in level.get("cores", []):
		i += 1
		var body := StaticBody3D.new()
		body.name = "core%d" % i
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Block.PLACEHOLDER_COLORS.get("core_gold", Color.GOLD)
		ShapeBuilder.build(body, shapes.get(core_shape, {}), mat)
		body.position = Vector3(float(c["x"]), float(c["y"]), float(c["z"]))
		body.set_meta(META_CORE, {"attach": c.get("attach", "rest")})
		root.add_child(body)
	return root


## Level dictionary from the preview nodes (baked: blocks / cores / keystones listed explicitly).
static func read(root: Node3D) -> Dictionary:
	var level: Dictionary = (root.get_meta(META_HEADER, {}) as Dictionary).duplicate(true)
	var blocks: Array = []
	var cores: Array = []
	var keystones: Array = []
	for n in root.get_children():
		var node := n as Node3D
		if node == null:
			continue
		var p := node.position
		if node.has_meta(META_BLOCK):
			var m: Dictionary = node.get_meta(META_BLOCK)
			var r := node.rotation_degrees
			var b := {"id": str(node.name), "shape": m["shape"], "mat": m["mat"],
					"x": snappedf(p.x, SNAP), "y": snappedf(p.y, SNAP), "z": snappedf(p.z, SNAP),
					"rot": [snappedf(r.x, SNAP), snappedf(r.y, SNAP), snappedf(r.z, SNAP)]}
			if not str(m.get("role", "")).is_empty():
				b["role"] = m["role"]
			blocks.append(b)
			if bool(m.get("keystone", false)):
				keystones.append(str(node.name))
		elif node.has_meta(META_CORE):
			cores.append({"x": snappedf(p.x, SNAP), "y": snappedf(p.y, SNAP), "z": snappedf(p.z, SNAP),
					"attach": (node.get_meta(META_CORE) as Dictionary).get("attach", "rest")})
	level["blocks"] = blocks
	level["cores"] = cores
	level["keystones"] = keystones
	return level
