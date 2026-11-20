class_name Platform
extends StaticBody3D
## The plinth the tower stands on. Top surface is y = 0, centred at the origin (docs/03 §2).
## Size comes from the level JSON, thickness/friction/bounce from rules.platform.
## The edge rule (Step 5) reads half_width / half_depth.

## Grey-box placeholder look (Faz 7 replaces it with a per-world mesh).
const PLACEHOLDER_COLOR := Color(0.62, 0.6, 0.56)

var half_width: float = 0.0
var half_depth: float = 0.0


## texture_path: the world's plinth texture (Faz 7); "" or missing = grey-box colour.
func build(width: float, depth: float, texture_path: String = "") -> void:
	half_width = width / 2.0
	half_depth = depth / 2.0
	var thickness := float(GameConfig.rule("platform.thickness"))
	var size := Vector3(width, thickness, depth)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = -thickness / 2.0
	add_child(col)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLACEHOLDER_COLOR
	if SurfaceTexture.apply(mat, texture_path):
		mat.albedo_color = Color.WHITE
	# Faz 7 look (rules.visuals.plinth): a chamfered cap that is the playing surface (same size as
	# the collider), and under it a slightly inset, darker (body_tint) pedestal. Visual only.
	var p: Dictionary = GameConfig.rule("visuals.plinth")
	var bevel := float(p["bevel"])
	var cap_h := float(p["cap_height"])
	var inset := float(p["body_inset"])
	var body_h := float(p["pedestal_depth"])
	_add_visual(ShapeBuilder.bevel_box_mesh(Vector3(width, cap_h, depth), bevel), Vector3(0, -cap_h / 2.0, 0), mat)
	var body := Vector3(maxf(width - 2.0 * inset, inset), body_h, maxf(depth - 2.0 * inset, inset))
	var body_mat := mat.duplicate() as StandardMaterial3D
	var tint := float(p["body_tint"])
	body_mat.albedo_color = Color(body_mat.albedo_color.r * tint, body_mat.albedo_color.g * tint, body_mat.albedo_color.b * tint)
	_add_visual(ShapeBuilder.bevel_box_mesh(body, bevel), Vector3(0, -cap_h - body_h / 2.0, 0), body_mat)

	var pm := PhysicsMaterial.new()
	pm.friction = float(GameConfig.rule("platform.friction"))
	pm.bounce = float(GameConfig.rule("platform.bounce"))
	physics_material_override = pm
	collision_layer = PhysicsLayers.PLATFORM
	collision_mask = 0


func _add_visual(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
