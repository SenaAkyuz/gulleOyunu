class_name FxPool
extends Node3D
## Pooled one-shot particle bursts (docs/07 §2, §7; S-008). Faz 1: one spark burst type.
## Pool size = rules.feel.max_concurrent_bursts; when every burst is busy the new one is skipped
## (bursts are merged, never more than the budget). Particle count = rules.feel.spark_amount x
## rules.quality.levels[quality.default].particles_mult. Listens to EventBus.ball_impact only
## (Block emits it when a ball contact is at least rules.feel.spark_min_impulse).

## Grey-box spark look until Faz 7 VFX (visual only, not a game rule).
const SPARK_COLOR := Color(1.0, 0.85, 0.4)
const SPARK_EMISSION_ENERGY := 2.0
## Sparks fly out in every direction from the contact point.
const SPARK_SPREAD_DEG := 180.0
const MIN_PARTICLES := 1
## Per-spark random variation: slowest spark = this x spark_speed; size between these scales.
const SPEED_MIN_RATIO := 0.5
const SCALE_MIN := 0.5
const SCALE_MAX := 1.0

var _bursts: Array[GPUParticles3D] = []
## A one-shot burst reports emitting = false as soon as every particle is spawned, while they are
## still flying; "busy" therefore lasts until the burst's `finished` signal.
var _busy: Array[bool] = []


func _ready() -> void:
	var amount := maxi(MIN_PARTICLES, roundi(float(GameConfig.rule("feel.spark_amount")) * _particles_mult()))
	for i in int(GameConfig.rule("feel.max_concurrent_bursts")):
		var p := _make_spark_burst(amount)
		add_child(p)
		p.finished.connect(_on_burst_finished.bind(_bursts.size()))
		_bursts.append(p)
		_busy.append(false)
	EventBus.ball_impact.connect(_on_ball_impact)


## Number of bursts currently playing.
func active_count() -> int:
	return _busy.count(true)


func _on_ball_impact(pos: Vector3, _impulse: float, _material: String) -> void:
	spark(pos)


## Plays a spark burst at `pos`. Returns false when the pool is exhausted.
func spark(pos: Vector3) -> bool:
	for i in _bursts.size():
		if not _busy[i]:
			_busy[i] = true
			_bursts[i].global_position = pos
			_bursts[i].restart()
			return true
	return false


func _on_burst_finished(index: int) -> void:
	_busy[index] = false


func _particles_mult() -> float:
	var level := str(GameConfig.rule("quality.default"))
	return float(GameConfig.rule("quality.levels.%s.particles_mult" % level))


func _make_spark_burst(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = float(GameConfig.rule("feel.spark_lifetime_sec"))
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = SPARK_SPREAD_DEG
	var speed := float(GameConfig.rule("feel.spark_speed"))
	pm.initial_velocity_min = speed * SPEED_MIN_RATIO
	pm.initial_velocity_max = speed
	pm.gravity = Vector3.DOWN * float(GameConfig.rule("physics.gravity"))
	pm.scale_min = SCALE_MIN
	pm.scale_max = SCALE_MAX
	p.process_material = pm

	var mesh := SphereMesh.new()
	var size := float(GameConfig.rule("feel.spark_size"))
	mesh.radius = size / 2.0
	mesh.height = size
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SPARK_COLOR
	mat.emission_enabled = true
	mat.emission = SPARK_COLOR
	mat.emission_energy_multiplier = SPARK_EMISSION_ENERGY
	mesh.material = mat
	p.draw_pass_1 = mesh
	# Bursts start invisible; the AABB must cover the burst wherever it is moved.
	p.visibility_aabb = AABB(Vector3.ONE * -speed, Vector3.ONE * speed * 2.0)
	return p
