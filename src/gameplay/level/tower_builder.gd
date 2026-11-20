class_name TowerBuilder
extends Node3D
## Spawns the level's blocks and cores (docs/03 §2.1). Template "structures" must already be
## expanded into "blocks" (LevelExpander). Bodies spawn asleep (rules.physics.spawn_sleeping)
## so the tower does not move before the first hit.
## Jolt ignores a sleep request made before the body's first physics tick, so bodies spawn
## frozen (static) for exactly one tick and are then released straight into sleep.

const BLOCK_SCENE: PackedScene = preload("res://src/gameplay/blocks/block.tscn")

## Simulation / check towers: every block is `silent` (no EventBus signals).
var silent: bool = false
var blocks: Array[Block] = []
var cores: Array[Block] = []


func build(level: Dictionary) -> void:
	clear()
	var keystones: Array = level.get("keystones", [])
	var index := 0
	for bd: Dictionary in level.get("blocks", []):
		index += 1
		var id := str(bd.get("id", "b%02d" % index))
		var b := _spawn(id, str(bd["shape"]), str(bd["mat"]), _pos(bd), _rot(bd))
		if b:
			b.is_keystone = keystones.has(id)
			blocks.append(b)

	var core_shape := str(GameConfig.rule("objective_defaults.core_shape"))
	var core_mat := str(GameConfig.rule("objective_defaults.core_material"))
	index = 0
	for cd: Dictionary in level.get("cores", []):
		index += 1
		if str(cd.get("attach", "rest")) != "rest":
			push_warning("Tower: küre bağlantısı '%s' Faz 5'te gelecek; küre serbest konuyor" % cd.get("attach"))
		var c := _spawn("core%d" % index, core_shape, core_mat, _pos(cd), Vector3.ZERO)
		if c:
			cores.append(c)
	_release_after_first_tick()


## Called without await: runs until the next physics tick, then unfreezes every body into sleep.
func _release_after_first_tick() -> void:
	await get_tree().physics_frame
	var sleep := bool(GameConfig.rule("physics.spawn_sleeping"))
	for b in all_bodies():
		if is_instance_valid(b):
			b.freeze = false
			b.sleeping = sleep


func clear() -> void:
	for b in all_bodies():
		b.queue_free()
	blocks.clear()
	cores.clear()


func all_bodies() -> Array[Block]:
	var out: Array[Block] = []
	out.append_array(blocks)
	out.append_array(cores)
	return out


func wake_all() -> void:
	for b in all_bodies():
		b.sleeping = false


## Bodies that are at rest or out of play (broken / retired below fall_kill_y count as resting).
func sleeping_count() -> int:
	var n := 0
	for b in all_bodies():
		if b.sleeping or not b.visible:
			n += 1
	return n


func max_drift() -> float:
	var d := 0.0
	for b in all_bodies():
		if b.visible:
			d = maxf(d, b.drift())
	return d


func broken_count() -> int:
	var n := 0
	for b in blocks:
		if b.is_broken:
			n += 1
	return n


func show_hp(on: bool) -> void:
	for b in all_bodies():
		b.show_hp(on)


func _spawn(id: String, shape_name: String, mat: String, pos: Vector3, rot_deg: Vector3) -> Block:
	var b: Block = BLOCK_SCENE.instantiate()
	if not b.setup(id, shape_name, mat, pos, rot_deg):
		b.free()
		return null
	b.silent = silent
	b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	b.freeze = true
	add_child(b)
	b.spawn_position = b.global_position
	return b


static func _pos(d: Dictionary) -> Vector3:
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))


static func _rot(d: Dictionary) -> Vector3:
	return ShapeBuilder.to_vec3(d.get("rot", [0, 0, 0]))
