class_name CameraShake
extends Node
## Trauma-based screen shake (docs/07 §2). Child of the level camera; visual only, never moves bodies.
## ball_impact adds trauma = impulse x rules.feel.shake_trauma_per_impulse (clamped to 1);
## shake = trauma^2 so light hits barely move and heavy hits punch. Decays in REAL time
## (rules.feel.shake_decay per second) so slow-mo does not freeze the camera off-centre.
## Golden rule (ordino-game-feel): while the referee is AIMING, shake is 0.

const MAX_TRAUMA := 1.0
## Smallest time scale used to convert scaled delta back to real time.
const MIN_TIME_SCALE := 0.0001
## Summed sines at unrelated rates give a smooth wobble instead of per-frame noise
## (visual pattern constants, not game rules).
const RATE_X := 1.7
const RATE_Y := 2.3
const RATE_ROLL := 1.1

var trauma: float = 0.0

var _camera: Camera3D
var _base: Transform3D
var _active: bool = false
var _t: float = 0.0
var _aiming: bool = true


func _ready() -> void:
	_camera = get_parent() as Camera3D
	EventBus.ball_impact.connect(_on_ball_impact)
	EventBus.referee_state_changed.connect(_on_referee_state_changed)


func add_trauma(amount: float) -> void:
	if _aiming or _camera == null:
		return
	if not _active:
		_base = _camera.transform  # camera is configured by the level before any impact
		_active = true
	trauma = clampf(trauma + amount, 0.0, MAX_TRAUMA)


## Current visual shake strength (0..1).
func shake() -> float:
	return trauma * trauma


func _on_ball_impact(_pos: Vector3, impulse: float, _material: String) -> void:
	add_trauma(impulse * float(GameConfig.rule("feel.shake_trauma_per_impulse")))


func _on_referee_state_changed(state_name: String) -> void:
	_aiming = state_name == "AIMING"
	if _aiming:
		_stop()


func _process(delta: float) -> void:
	if not _active:
		return
	var real_dt := delta / maxf(Engine.time_scale, MIN_TIME_SCALE)
	trauma = maxf(trauma - float(GameConfig.rule("feel.shake_decay")) * real_dt, 0.0)
	if trauma <= 0.0:
		_stop()
		return
	_t += real_dt * float(GameConfig.rule("feel.shake_frequency"))
	var s := shake()
	var max_offset := float(GameConfig.rule("feel.shake_max_offset"))
	var max_roll := deg_to_rad(float(GameConfig.rule("feel.shake_max_rotation_deg")))
	_camera.h_offset = max_offset * s * sin(_t * RATE_X)
	_camera.v_offset = max_offset * s * sin(_t * RATE_Y)
	_camera.transform = _base * Transform3D(Basis(Vector3.BACK, max_roll * s * sin(_t * RATE_ROLL)), Vector3.ZERO)


func _stop() -> void:
	trauma = 0.0
	if not _active:
		return
	_active = false
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_camera.transform = _base
