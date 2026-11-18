class_name AimInput
extends Node
## tap_target aiming (K-011, plan §4):
##  press  -> cast a ray from the touched screen point; if it hits a block/core/platform, aim there
##  drag   -> target follows the finger (fine-tune)
##  release-> fire at the last surface under the finger; over empty sky nothing happens (aim.on_miss = ignore)
## Only mouse events are handled: Godot emulates mouse from touch by default, so phones work too
## and nothing is handled twice. Ray casts run in _physics_process (safe space-state access).

signal target_changed(has_target: bool, target: Vector3)

const MODE_TAP_TARGET := "tap_target"

## Off while a ball is in flight / the tower settles / the level is over (LevelReferee state).
var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			_pressed = false
			_fire_pending = false
			_query_pending = false
			has_target = false
			if is_node_ready():
				_cannon.show_target(false, Vector3.ZERO)
var has_target: bool = false
var target: Vector3 = Vector3.ZERO

var _pressed: bool = false
var _screen_pos: Vector2 = Vector2.ZERO
var _query_pending: bool = false
var _fire_pending: bool = false

@onready var _cannon: Cannon = get_parent()


func _ready() -> void:
	var mode := str(GameConfig.rule("aim.mode"))
	if mode != MODE_TAP_TARGET:
		push_warning("AimInput: '%s' modu Adım 12'de gelecek; şimdilik tap_target kullanılıyor" % mode)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pressed = true
			_screen_pos = button.position
			_query_pending = true
		elif _pressed:
			_pressed = false
			_screen_pos = button.position
			_query_pending = true
			_fire_pending = true
		return
	var motion := event as InputEventMouseMotion
	if motion and _pressed:
		_screen_pos = motion.position
		_query_pending = true


func _physics_process(_delta: float) -> void:
	if not _query_pending:
		return
	_query_pending = false
	_update_target()
	if _fire_pending:
		_fire_pending = false
		if has_target:
			_cannon.fire_at(target)
		has_target = false
	elif has_target:
		_cannon.aim_at(target)
	_cannon.show_target(has_target and _pressed, target)
	target_changed.emit(has_target and _pressed, target)


func _update_target() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		has_target = false
		return
	var from := camera.project_ray_origin(_screen_pos)
	var to := from + camera.project_ray_normal(_screen_pos) * camera.far
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.AIM_RAY_MASK)
	var hit := _cannon.get_world_3d().direct_space_state.intersect_ray(query)
	has_target = not hit.is_empty()
	if has_target:
		target = hit["position"]
