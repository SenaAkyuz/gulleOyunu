extends Node3D
## Builds a level from its JSON (docs/02 §4.2): camera, platform, tower, referee, cannon, HUD.
## Aiming is only enabled while the referee is in AIMING (EventBus.referee_state_changed).
## Play: left mouse / touch = aim at a surface, release = fire.
## Dev keys: G = play-area guide, Space = wake every body, Tab = select body,
## arrows = push selected body (rules.dev.nudge_impulse), H = hp labels, R = restart level.

## Empty = rules.dev.start_level_id
@export var level_id: String = ""

var level_data: Dictionary = {}
var _info_static: String = ""
var _selected: int = -1
var _hp_visible: bool = false

@onready var _camera: LevelCamera = $Camera3D
@onready var _platform: Platform = $Platform
@onready var _tower: TowerBuilder = $Tower
@onready var _referee: LevelReferee = $LevelReferee
@onready var _cannon: Cannon = $Cannon
@onready var _balls: Node3D = $Balls
@onready var _area_guide: MeshInstance3D = $AreaGuide
@onready var _hud: Hud = $HUD
@onready var _aim: AimInput = $Cannon/AimInput


func _ready() -> void:
	if level_id.is_empty():
		level_id = str(GameConfig.rule("dev.start_level_id"))
	level_data = GameConfig.level(level_id)
	if level_data.is_empty():
		push_error("Level: bölüm yüklenemedi: " + level_id)
		return

	_camera.configure(_camera_settings())

	var plat: Dictionary = level_data.get("platform", {})
	_platform.build(float(plat.get("width")), float(plat.get("depth")))
	_tower.build(level_data)
	EventBus.referee_state_changed.connect(_on_referee_state_changed)
	_referee.setup(level_data, _tower, _platform)
	_hud.setup(int(level_data.get("index", 0)), _referee.objective_type)

	_cannon.position = ShapeBuilder.to_vec3(GameConfig.rule("cannon.position"))
	var dots: Variant = level_data.get("aim_preview_dots")
	if dots == null:
		dots = GameConfig.rule("aim.default_preview_dots")
	_cannon.setup(_balls, GameConfig.starting_ball_id(), int(dots))

	_build_area_guide()
	_info_static = "%s · %s · %d blok + %d küre · top: %s\nSol tık: nişan · bırak: ateş   H hp · G alan · Boşluk · Tab seç · Oklar it · R baştan · F12" % [
		level_id, _referee.objective_type, _tower.blocks.size(), _tower.cores.size(), _cannon.ball_id]


func _physics_process(_delta: float) -> void:
	var bodies := _tower.all_bodies()
	var sel := bodies[_selected].block_id if _selected >= 0 and _selected < bodies.size() else "-"
	_hud.set_dev_text("%s\nDurum: %s  Duran: %d/%d  Seçili: %s  Düşen: %d  Kırılan: %d  Temizlik: %%%d" % [
		_info_static, _referee.state_name(), _tower.sleeping_count(), bodies.size(), sel,
		_referee.fallen_block_count(), _tower.broken_count(), roundi(_referee.clear_ratio * 100.0)])


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not (key and key.pressed):
		return
	# Arrow keys may auto-repeat (hold to keep pushing); the others react once per press.
	match key.keycode:
		KEY_LEFT:
			_nudge(Vector3.LEFT)
		KEY_RIGHT:
			_nudge(Vector3.RIGHT)
		KEY_DOWN:
			_nudge(Vector3.BACK)     # +z: towards the camera
		KEY_UP:
			_nudge(Vector3.FORWARD)  # -z: away from the camera
	if key.echo:
		return
	match key.keycode:
		KEY_G:
			_area_guide.visible = not _area_guide.visible
		KEY_H:
			_hp_visible = not _hp_visible
			_tower.show_hp(_hp_visible)
		KEY_SPACE:
			_tower.wake_all()
		KEY_TAB:
			_select(_selected + 1)
		KEY_R:
			get_tree().reload_current_scene()


func _on_referee_state_changed(_state_name: String) -> void:
	_aim.enabled = _referee.is_aiming()


func _select(index: int) -> void:
	var bodies := _tower.all_bodies()
	if bodies.is_empty():
		return
	if _selected >= 0 and _selected < bodies.size():
		bodies[_selected].set_highlight(false)
	_selected = posmod(index, bodies.size())
	bodies[_selected].set_highlight(true)


func _nudge(direction: Vector3) -> void:
	var bodies := _tower.all_bodies()
	if _selected < 0 or _selected >= bodies.size():
		return
	var b := bodies[_selected]
	if not b.visible:
		return
	b.sleeping = false
	b.apply_central_impulse(direction * float(GameConfig.rule("dev.nudge_impulse")))


## rules.camera, overridden key-by-key by level.camera_override (docs/02 §2).
func _camera_settings() -> Dictionary:
	var cfg: Dictionary = (GameConfig.rule("camera") as Dictionary).duplicate()
	var override: Variant = level_data.get("camera_override")
	if override is Dictionary:
		cfg.merge(override, true)
	return cfg


## Yellow wireframe box of the playable tower area (rules.dev.play_area_guide).
func _build_area_guide() -> void:
	var guide: Dictionary = GameConfig.rule("dev.play_area_guide")
	var a := ShapeBuilder.to_vec3(guide["min"])
	var b := ShapeBuilder.to_vec3(guide["max"])
	var c: Array[Vector3] = [
		Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	var edges: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in edges:
		mesh.surface_add_vertex(c[e.x])
		mesh.surface_add_vertex(c[e.y])
	mesh.surface_end()
	_area_guide.mesh = mesh
