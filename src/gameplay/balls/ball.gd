class_name Ball
extends RigidBody3D
## A fired ball (docs/02 §6.4): RigidBody3D with CCD, no axis locks, values from balls.json.
## Behaviour is a BallBehavior strategy picked by balls.json -> behavior.
## Expires after max_life_sec, when it falls below fall_kill_y, or when it comes to rest.

const BEHAVIOR_PATH := "res://src/gameplay/balls/behaviors/%s_behavior.gd"
## Grey-box look until Faz 5/7 ball visuals.
const PLACEHOLDER_COLOR := Color(0.15, 0.15, 0.17)

signal expired(ball: Ball)

var ball_id: String = ""
var behavior: BallBehavior
var _life_left: float = 0.0
var _kill_y: float = 0.0
var _expired: bool = false


func setup(id: String) -> bool:
	var def := GameConfig.ball(id)
	if def.is_empty():
		push_error("Ball: bilinmeyen top '%s'" % id)
		return false
	ball_id = id
	name = "Ball_" + id
	var radius := float(def["radius"])
	mass = float(def["mass"])
	_life_left = float(def["max_life_sec"])
	_kill_y = float(GameConfig.rule("physics.fall_kill_y"))

	var shape := SphereShape3D.new()
	shape.radius = radius
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLACEHOLDER_COLOR
	mat.metallic = 0.7
	mat.roughness = 0.35
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

	continuous_cd = true
	can_sleep = true
	collision_layer = PhysicsLayers.BALL
	collision_mask = PhysicsLayers.PLATFORM | PhysicsLayers.BLOCK | PhysicsLayers.CORE

	var script_path := BEHAVIOR_PATH % str(def["behavior"])
	if not ResourceLoader.exists(script_path):
		push_error("Ball: davranış dosyası yok: " + script_path)
		return false
	behavior = load(script_path).new()
	behavior.ball = self
	behavior.params = def.get("params", {})
	return true


## Call after the ball is in the tree, at the muzzle.
func launch(velocity: Vector3) -> void:
	linear_velocity = velocity
	behavior.on_launch()
	EventBus.ball_fired.emit(ball_id)


func _physics_process(delta: float) -> void:
	if _expired:
		return
	behavior.on_physics(delta)
	_life_left -= delta
	if _life_left <= 0.0 or global_position.y < _kill_y or sleeping:
		expire()


func expire() -> void:
	if _expired:
		return
	_expired = true
	behavior.on_expire()
	expired.emit(self)
	EventBus.ball_expired.emit(ball_id)
	queue_free()
