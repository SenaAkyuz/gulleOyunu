class_name Platform
extends StaticBody3D
## The plinth the tower stands on. Top surface is y = 0, centred at the origin (docs/03 §2).
## Size comes from the level JSON, thickness/friction/bounce from rules.platform.
## The edge rule (Step 5) reads half_width / half_depth.

## Grey-box placeholder look (Faz 7 replaces it with a per-world mesh).
const PLACEHOLDER_COLOR := Color(0.62, 0.6, 0.56)

var half_width: float = 0.0
var half_depth: float = 0.0


func build(width: float, depth: float) -> void:
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

	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLACEHOLDER_COLOR
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = -thickness / 2.0
	add_child(mi)

	var pm := PhysicsMaterial.new()
	pm.friction = float(GameConfig.rule("platform.friction"))
	pm.bounce = float(GameConfig.rule("platform.bounce"))
	physics_material_override = pm
	collision_layer = PhysicsLayers.PLATFORM
	collision_mask = 0
