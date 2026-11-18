class_name Block
extends RigidBody3D
## One tower piece = shape (shapes.json) + material (materials.json) (docs/02 §6.2).
## The Golden Core is also a Block (core_sphere + core_gold, flag "objective").
## Origin = centre of the shape's base (y = bottom face), rotation = [rx, ry, rz] degrees, Euler YXZ.
## No axis locks (K-002). Damage (Step 8) and the edge rule (Step 5) come later.

## Grey-box colours until Faz 7 textures arrive (visual only, not a game rule).
const PLACEHOLDER_COLORS := {
	"stone": Color(0.93, 0.87, 0.74),
	"sandstone": Color(0.9, 0.75, 0.5),
	"wood": Color(0.55, 0.36, 0.2),
	"crate": Color(0.68, 0.5, 0.3),
	"crystal_amber": Color(1.0, 0.6, 0.12, 0.8),
	"crystal_cyan": Color(0.2, 0.9, 0.9, 0.8),
	"crystal_purple": Color(0.7, 0.35, 1.0, 0.8),
	"ice": Color(0.75, 0.9, 1.0, 0.7),
	"metal": Color(0.55, 0.58, 0.62),
	"core_gold": Color(1.0, 0.78, 0.2),
}
const FALLBACK_COLOR := Color(0.6, 0.6, 0.6)
## Edge rule feedback: a body counted as fallen turns grey (docs/02 §2 "gri parıltı", grey-box version).
const FALLEN_COLOR := Color(0.45, 0.45, 0.45)
const FALLEN_TINT := 0.75
## Dev selection highlight (Tab + arrow keys).
const HIGHLIGHT_EMISSION := Color(1.0, 1.0, 1.0)
const HIGHLIGHT_ENERGY := 0.6

var block_id: String = ""
var shape_id: String = ""
var material_id: String = ""
var is_objective: bool = false
var is_keystone: bool = false
var hp: float = 0.0
## Global position right after spawning (used to measure drift / stability).
var spawn_position: Vector3 = Vector3.ZERO
## Set by LevelReferee via the edge rule.
var is_fallen: bool = false

var _visual_mat: StandardMaterial3D
var _base_color: Color
var _base_emission_enabled: bool
var _base_emission: Color
var _base_emission_energy: float


## Configures the body before it enters the tree. Returns false if shape/material is unknown.
func setup(id: String, shape_name: String, material_name: String, pos: Vector3, rot_deg: Vector3) -> bool:
	var shape_def := GameConfig.shape(shape_name)
	var mat := GameConfig.material(material_name)
	if shape_def.is_empty() or mat.is_empty():
		push_error("Block %s: bilinmeyen şekil '%s' veya malzeme '%s'" % [id, shape_name, material_name])
		return false
	block_id = id
	shape_id = shape_name
	material_id = material_name
	name = id

	_visual_mat = _visual_material(material_name)
	_base_color = _visual_mat.albedo_color
	_base_emission_enabled = _visual_mat.emission_enabled
	_base_emission = _visual_mat.emission
	_base_emission_energy = _visual_mat.emission_energy_multiplier
	var volume := ShapeBuilder.build(self, shape_def, _visual_mat)
	mass = volume * float(mat["density"])
	var pm := PhysicsMaterial.new()
	pm.friction = float(mat["friction"])
	pm.bounce = float(mat["bounce"])
	physics_material_override = pm

	var flags: Array = mat.get("flags", [])
	is_objective = flags.has("objective")
	hp = float(mat["hp"])

	collision_layer = PhysicsLayers.CORE if is_objective else PhysicsLayers.BLOCK
	collision_mask = PhysicsLayers.PLATFORM | PhysicsLayers.BLOCK | PhysicsLayers.CORE | PhysicsLayers.BALL
	can_sleep = true
	position = pos
	rotation_degrees = rot_deg
	return true


func set_fallen(value: bool) -> void:
	if value == is_fallen:
		return
	is_fallen = value
	var target := FALLEN_COLOR
	target.a = _base_color.a
	_visual_mat.albedo_color = _base_color.lerp(target, FALLEN_TINT) if value else _base_color


func set_highlight(on: bool) -> void:
	if on:
		_visual_mat.emission_enabled = true
		_visual_mat.emission = HIGHLIGHT_EMISSION
		_visual_mat.emission_energy_multiplier = HIGHLIGHT_ENERGY
	else:
		_visual_mat.emission_enabled = _base_emission_enabled
		_visual_mat.emission = _base_emission
		_visual_mat.emission_energy_multiplier = _base_emission_energy


func drift() -> float:
	return global_position.distance_to(spawn_position)


## Real centre of mass in world space (the edge rule uses this, docs/02 §2).
## Note: the `center_of_mass` property is only meaningful in CUSTOM mode; with AUTO the engine's
## computed value lives in the body's direct state.
func world_center_of_mass() -> Vector3:
	var state := PhysicsServer3D.body_get_direct_state(get_rid())
	if state == null:
		return global_position
	return global_transform * state.center_of_mass_local


func _visual_material(material_name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var color: Color = PLACEHOLDER_COLORS.get(material_name, FALLBACK_COLOR)
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.3
	if material_name == str(GameConfig.rule("objective_defaults.core_material")):
		m.metallic = 0.8
		m.roughness = 0.25
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.4
	return m
