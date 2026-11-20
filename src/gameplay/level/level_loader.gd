class_name LevelLoader
extends Node3D
## Builds a level from its JSON (docs/02 §4.2): camera, platform, tower, referee, cannon, HUD.
## Aiming is only enabled while the referee is in AIMING (EventBus.referee_state_changed).
## Play: left mouse / touch = aim at a surface, release = fire.
## Dev keys: G = play-area guide, Space = wake every body, Tab = select body,
## arrows = push selected body (rules.dev.nudge_impulse), H = hp labels, R = restart level,
## F1 = Dev Panel (src/ui/dev_panel), P = stress tower on/off (StressLevel, S-008),
## N / B = next / previous level file. Template levels are expanded by LevelExpander.

## Empty = the dev-selected level (N/B keys), else rules.dev.start_level_id
@export var level_id: String = ""

## P key: the next (re)load builds the stress tower instead of the level. Survives a reload.
static var stress_mode: bool = false
## N / B keys: level chosen in this session (until menus arrive in Faz 4). Survives a reload.
static var dev_level_id: String = ""
## Dev / editor "Test Et": a level dictionary to play instead of a file (cleared by N/B).
static var dev_level_data: Dictionary = {}
## Where the current level came from (LevelGenerator.describe), shown in the Dev Panel and HUD.
static var current_source: String = ""

var level_data: Dictionary = {}
## Peak active bodies since the level started (S-008 budget check).
var peak_active: int = 0
var _info_static: String = ""
var _selected: int = -1
var _hp_visible: bool = false
var _loaded: bool = false

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
		level_id = dev_level_id if not dev_level_id.is_empty() else str(GameConfig.rule("dev.start_level_id"))
	if stress_mode:
		level_data = StressLevel.build()
	elif not dev_level_data.is_empty():
		level_data = LevelExpander.expand(dev_level_data)
		level_id = str(level_data.get("id", level_id))
	else:
		# A level file if there is one, else the generator (docs/03 §8); may take a moment.
		_hud.set_dev_text("Bölüm hazırlanıyor: %s ..." % level_id)
		var res: Dictionary = await LevelGenerator.resolve(level_id, self)
		level_data = res.get("level", {})
		current_source = LevelGenerator.describe(res)
	if stress_mode or not dev_level_data.is_empty():
		current_source = "stres" if stress_mode else "bellek (editör / test)"
	if level_data.is_empty() and current_source.begins_with(LevelGenerator.SOURCE_PENDING):
		# Hand-made slot (docs/03 §9) without a file and without a usable candidate: not an error.
		_hud.show_notice("L%02d" % LevelGenerator.parse_id(level_id).y, LevelGenerator.SOURCE_PENDING)
		_hud.set_dev_text("Kaynak: %s\nN/B: başka bölüm" % current_source)
		return
	if level_data.is_empty():
		push_error("Level: bölüm yüklenemedi: " + level_id)
		_hud.set_dev_text("Bölüm yüklenemedi: %s (Output panelinde ayrıntı)" % level_id)
		return

	_camera.configure(_camera_settings())

	var plat: Dictionary = level_data.get("platform", {})
	_platform.build(float(plat.get("width")), float(plat.get("depth")))
	_tower.build(level_data)
	EventBus.referee_state_changed.connect(_on_referee_state_changed)
	_referee.setup(level_data, _tower, _platform)
	_hud.setup(int(level_data.get("index", 0)), _referee.objective_type, Progress.stars_for(level_id))

	_cannon.position = ShapeBuilder.to_vec3(GameConfig.rule("cannon.position"))
	var dots: Variant = level_data.get("aim_preview_dots")
	if dots == null:
		dots = GameConfig.rule("aim.default_preview_dots")
	_cannon.setup(_balls, GameConfig.starting_ball_id(), int(dots))

	_build_area_guide()
	_info_static = "%s · %s · %d blok + %d küre · top: %s\nSol tık: nişan · bırak: ateş   H hp · G alan · Boşluk · Tab seç · Oklar it · R baştan · N/B bölüm · F1 panel · P stres · F12" % [
		str(level_data.get("id", level_id)), _referee.objective_type, _tower.blocks.size(), _tower.cores.size(), _cannon.ball_id]
	_info_static = "Kaynak: %s\n%s" % [current_source, _info_static]
	_loaded = true


func _physics_process(_delta: float) -> void:
	if not _loaded:
		return
	var active := active_body_count()
	peak_active = maxi(peak_active, active)
	_hud.set_perf(Engine.get_frames_per_second(), active, peak_active)
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
		KEY_P:
			stress_mode = not stress_mode
			get_tree().reload_current_scene()
		KEY_N:
			_switch_level(1)
		KEY_B:
			_switch_level(-1)


## Dev: next / previous level of the current world (files or generator), wraps around.
func _switch_level(step: int) -> void:
	var wi := LevelGenerator.parse_id(level_id)
	if wi.x < 0:
		wi = LevelGenerator.parse_id(str(GameConfig.rule("dev.start_level_id")))
	var count := int(LevelGenerator.world_by_index(wi.x).get("level_count", 0))
	if count <= 0:
		return
	dev_level_id = LevelGenerator.level_id(wi.x, posmod(wi.y - 1 + step, count) + 1)
	dev_level_data = {}
	stress_mode = false
	get_tree().reload_current_scene()


## Simulated (awake, not frozen, still in play) rigid bodies: tower pieces + balls (S-008).
func active_body_count() -> int:
	var n := 0
	for b in _tower.all_bodies():
		if b.visible and not b.sleeping and not b.freeze:
			n += 1
	for ball in _balls.get_children():
		var rb := ball as RigidBody3D
		if rb and not rb.sleeping:
			n += 1
	return n


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
