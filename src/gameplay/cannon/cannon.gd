class_name Cannon
extends Node3D
## The cannon at the bottom of the screen (docs/01 §3.2). Turns smoothly towards the aim
## direction (rules.aim.aim_smoothing) and fires a Ball from the muzzle with the launch
## velocity from Ballistics (fixed balls.json launch_speed, rules.aim.arc).

const BALL_SCENE: PackedScene = preload("res://src/gameplay/balls/ball.tscn")

var ball_id: String = ""

var _balls_parent: Node3D
var _arc: String = ""
var _smoothing: float = 0.0
var _target_dir: Vector3 = Vector3.FORWARD
var _preview_target: Vector3 = Vector3.ZERO
var _preview_on: bool = false

@onready var _yaw: Node3D = $Yaw
@onready var _pitch: Node3D = $Yaw/Pitch
@onready var _muzzle: Marker3D = $Yaw/Pitch/Muzzle
@onready var _target_marker: MeshInstance3D = $TargetMarker
@onready var _preview: TrajectoryPreview = $TrajectoryPreview


## preview_dots: the level's aim_preview_dots (or rules.aim.default_preview_dots).
func setup(balls_parent: Node3D, start_ball_id: String, preview_dots: int) -> void:
	_balls_parent = balls_parent
	ball_id = start_ball_id
	_arc = str(GameConfig.rule("aim.arc"))
	_smoothing = float(GameConfig.rule("aim.aim_smoothing"))
	_preview.setup(preview_dots, float(GameConfig.rule("aim.preview_dot_interval_sec")))
	var to_tower := Vector3(-global_position.x, 0.0, -global_position.z)
	_target_dir = to_tower.normalized() if to_tower.length() > 0.0 else Vector3.FORWARD
	_apply_direction(_target_dir)
	show_target(false, Vector3.ZERO)


func muzzle_position() -> Vector3:
	return _muzzle.global_position


func launch_speed() -> float:
	return float(GameConfig.ball(ball_id)["launch_speed"])


## Read live so the Dev Panel's gravity slider applies to the next shot.
func gravity() -> float:
	return float(GameConfig.rule("physics.gravity"))


## {"velocity": Vector3, "reachable": bool} from the muzzle to target.
func solve_to(target: Vector3) -> Dictionary:
	return Ballistics.solve(muzzle_position(), target, launch_speed(), gravity(), _arc)


func aim_at(target: Vector3) -> void:
	_target_dir = (solve_to(target)["velocity"] as Vector3).normalized()


func fire_at(target: Vector3) -> Ball:
	var velocity: Vector3 = solve_to(target)["velocity"]
	var ball: Ball = BALL_SCENE.instantiate()
	if not ball.setup(ball_id):
		ball.free()
		return null
	_balls_parent.add_child(ball)
	ball.global_position = muzzle_position()
	ball.launch(velocity)
	_target_dir = velocity.normalized()
	_apply_direction(_target_dir)
	return ball


## Target marker + dotted trajectory while the player is aiming.
func show_target(visible_now: bool, pos: Vector3) -> void:
	_target_marker.visible = visible_now
	_preview_on = visible_now
	_preview_target = pos
	if visible_now:
		_target_marker.global_position = pos
	else:
		_preview.hide_path()


func _process(delta: float) -> void:
	var current := -_pitch.global_basis.z
	var weight := 1.0 - exp(-_smoothing * delta)
	_apply_direction(current.slerp(_target_dir, weight))
	if _preview_on:
		# Recomputed every frame: the muzzle moves while the barrel turns.
		var from := muzzle_position()
		var velocity: Vector3 = solve_to(_preview_target)["velocity"]
		_preview.show_path(from, velocity, gravity(),
				Ballistics.time_to_reach(from, _preview_target, velocity))


## Barrel points along -Z: yaw around Y, then pitch around X.
func _apply_direction(dir: Vector3) -> void:
	if dir.length_squared() == 0.0:
		return
	dir = dir.normalized()
	_yaw.rotation.y = atan2(-dir.x, -dir.z)
	_pitch.rotation.x = asin(clampf(dir.y, -1.0, 1.0))
