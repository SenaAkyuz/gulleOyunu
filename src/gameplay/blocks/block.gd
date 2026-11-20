class_name Block
extends RigidBody3D
## One tower piece = shape (shapes.json) + material (materials.json) (docs/02 §6.2).
## The Golden Core is also a Block (core_sphere + core_gold, flags "objective", "unbreakable").
## Origin = centre of the shape's base (y = bottom face), rotation = [rx, ry, rz] degrees, Euler YXZ.
## No axis locks (K-002).
## Damage (docs/02 §6.3): every physics step the contact impulses are turned into damage
## (BlockDamage); hp < crack ratio -> darker, hp <= 0 -> broken (hidden, collision off, kept for
## accounting so the referee can still count it). Faz 7 replaces this with fractured meshes.

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
## Grey-box "crack": darken instead of a crack texture.
const CRACK_DARKEN := 0.6
## Dev selection highlight (Tab + arrow keys).
const HIGHLIGHT_EMISSION := Color(1.0, 1.0, 1.0)
const HIGHLIGHT_ENERGY := 0.6
## docs/02 §6.2: contact reporting for damage.
const MAX_CONTACTS_REPORTED := 4
## When a block breaks, sleeping bodies within its bounds + this margin are woken
## (Jolt does not wake bodies whose support simply disappears).
const WAKE_MARGIN := 0.15
## Dev hp label (H key).
const HP_LABEL_FONT_SIZE := 48
const HP_LABEL_OFFSET_Y := 0.3

var block_id: String = ""
var shape_id: String = ""
var material_id: String = ""
var is_objective: bool = false
var is_unbreakable: bool = false
var is_keystone: bool = false
var hp: float = 0.0
var max_hp: float = 0.0
## Shape volume in m^3 (clear_percent measures by volume, K-018).
var volume: float = 0.0
## Global position right after spawning (used to measure drift / stability).
var spawn_position: Vector3 = Vector3.ZERO
## Set by LevelReferee via the edge rule.
var is_fallen: bool = false
var is_broken: bool = false
## Simulation / check copies (LevelSim, SupportCheck.physics_drift): no EventBus signals, so a
## simulated break never pays crystal gold, shakes the camera or counts for the referee.
var silent: bool = false

var _impact_threshold: float = 0.0
var _crack_ratio: float = 0.0
var _spark_min_impulse: float = 0.0
var _visual_mat: StandardMaterial3D
var _base_color: Color
var _base_emission_enabled: bool
var _base_emission: Color
var _base_emission_energy: float
var _hp_label: Label3D


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
	volume = ShapeBuilder.build(self, shape_def, _visual_mat)
	mass = volume * float(mat["density"])
	var pm := PhysicsMaterial.new()
	pm.friction = float(mat["friction"])
	pm.bounce = float(mat["bounce"])
	physics_material_override = pm

	var flags: Array = mat.get("flags", [])
	is_objective = flags.has("objective")
	is_unbreakable = flags.has("unbreakable")
	max_hp = float(mat["hp"])
	hp = max_hp
	_impact_threshold = float(mat["impact_threshold"])
	_crack_ratio = float(GameConfig.rule("feel.crack_hp_ratio"))
	_spark_min_impulse = float(GameConfig.rule("feel.spark_min_impulse"))

	collision_layer = PhysicsLayers.CORE if is_objective else PhysicsLayers.BLOCK
	collision_mask = PhysicsLayers.PLATFORM | PhysicsLayers.BLOCK | PhysicsLayers.CORE | PhysicsLayers.BALL
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = MAX_CONTACTS_REPORTED
	position = pos
	rotation_degrees = rot_deg
	return true


## Turns this step's contact impulses into damage (docs/02 §6.3).
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_broken:
		return
	var total := 0.0
	var strongest_ball_hit := 0.0
	var ball_hit_pos := Vector3.ZERO
	for i in state.get_contact_count():
		var impulse := state.get_contact_impulse(i).length()
		var other := state.get_contact_collider_object(i)
		var mult := BlockDamage.DEFAULT_MULT
		var ball := other as Ball
		if ball:
			mult = BlockDamage.ball_multiplier(ball.ball_id, material_id)
			if impulse > strongest_ball_hit:
				strongest_ball_hit = impulse
				ball_hit_pos = state.get_contact_collider_position(i)
		total += BlockDamage.damage(impulse, _impact_threshold, mult)
	if strongest_ball_hit >= _spark_min_impulse:
		_emit_ball_impact.call_deferred(ball_hit_pos, strongest_ball_hit)
	if total > 0.0:
		_apply_damage.call_deferred(total)


func _apply_damage(amount: float) -> void:
	if is_broken or is_unbreakable:
		return
	hp = maxf(0.0, hp - amount)
	_refresh_color()
	_refresh_hp_label()
	if not silent:
		EventBus.block_damaged.emit(self, hp)
	if hp <= 0.0:
		_break()


## Faz 1: the block simply vanishes (no fracture pieces yet). Kept in the tree for accounting.
func _break() -> void:
	_wake_neighbours()
	is_broken = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	freeze = true
	if not silent:
		EventBus.block_broken.emit(self, material_id)


## Wakes every block/core touching this block's bounding box (grown by WAKE_MARGIN) so whatever
## rested on it falls once it is gone.
func _wake_neighbours() -> void:
	var size := ShapeBuilder.to_vec3(GameConfig.shape(shape_id)["size"])
	var box := BoxShape3D.new()
	box.size = size + Vector3.ONE * WAKE_MARGIN * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3.UP * size.y / 2.0)
	query.collision_mask = PhysicsLayers.BLOCK | PhysicsLayers.CORE
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		var body := hit["collider"] as RigidBody3D
		if body:
			body.sleeping = false


func _emit_ball_impact(pos: Vector3, impulse: float) -> void:
	if not silent:
		EventBus.ball_impact.emit(pos, impulse, material_id)


func set_fallen(value: bool) -> void:
	if value == is_fallen:
		return
	is_fallen = value
	_refresh_color()


func set_highlight(on: bool) -> void:
	if on:
		_visual_mat.emission_enabled = true
		_visual_mat.emission = HIGHLIGHT_EMISSION
		_visual_mat.emission_energy_multiplier = HIGHLIGHT_ENERGY
	else:
		_visual_mat.emission_enabled = _base_emission_enabled
		_visual_mat.emission = _base_emission
		_visual_mat.emission_energy_multiplier = _base_emission_energy


## Dev: floating hp number above the block (H key).
func show_hp(on: bool) -> void:
	if on and _hp_label == null:
		_hp_label = Label3D.new()
		_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hp_label.no_depth_test = true
		_hp_label.font_size = HP_LABEL_FONT_SIZE
		_hp_label.outline_size = HP_LABEL_FONT_SIZE / 4
		_hp_label.top_level = true
		add_child(_hp_label)
	if _hp_label:
		_hp_label.visible = on
		_refresh_hp_label()


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


func _process(_delta: float) -> void:
	if _hp_label and _hp_label.visible:
		_hp_label.global_position = world_center_of_mass() + Vector3.UP * HP_LABEL_OFFSET_Y


func _refresh_color() -> void:
	var color := _base_color
	if not is_unbreakable and max_hp > 0.0 and hp < max_hp * _crack_ratio:
		color = Color(color.r * CRACK_DARKEN, color.g * CRACK_DARKEN, color.b * CRACK_DARKEN, color.a)
	if is_fallen:
		var target := FALLEN_COLOR
		target.a = color.a
		color = color.lerp(target, FALLEN_TINT)
	_visual_mat.albedo_color = color


func _refresh_hp_label() -> void:
	if _hp_label == null:
		return
	_hp_label.text = "∞" if is_unbreakable else "%d" % ceili(hp)
	_hp_label.modulate = Color.WHITE if hp >= max_hp * _crack_ratio else Color.ORANGE_RED


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
