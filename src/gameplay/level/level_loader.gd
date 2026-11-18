extends Node3D
## Builds a level from its JSON (docs/02 §4.2).
## Camera, platform, tower, cannon placeholder and dev helpers.
## Cannon (Step 6) and referee (Step 9) are added in later steps.
## Dev keys: G = play-area guide, Space = wake every body (stability test).

## Empty = rules.dev.start_level_id
@export var level_id: String = ""

var level_data: Dictionary = {}
var _info_static: String = ""

@onready var _camera: LevelCamera = $Camera3D
@onready var _platform: Platform = $Platform
@onready var _tower: TowerBuilder = $Tower
@onready var _cannon_marker: Node3D = $CannonPlaceholder
@onready var _area_guide: MeshInstance3D = $AreaGuide
@onready var _info: Label = $HUD/InfoLabel


func _ready() -> void:
	if level_id.is_empty():
		level_id = str(GameConfig.rule("dev.start_level_id"))
	level_data = GameConfig.level(level_id)
	if level_data.is_empty():
		push_error("Level: bölüm yüklenemedi: " + level_id)
		return

	var cam_cfg := _camera_settings()
	_camera.configure(cam_cfg)

	var plat: Dictionary = level_data.get("platform", {})
	_platform.build(float(plat.get("width")), float(plat.get("depth")))
	_tower.build(level_data)

	var cannon_pos := _vec3(GameConfig.rule("cannon.position"))
	_cannon_marker.position = cannon_pos
	_cannon_marker.look_at(Vector3(0.0, cannon_pos.y, 0.0), Vector3.UP)

	_build_area_guide()
	_info_static = "%s · %d blok + %d küre\nG: kule alanı   Boşluk: kuleyi uyandır   F12: ekran görüntüsü" % [
		level_id, _tower.blocks.size(), _tower.cores.size()]


func _physics_process(_delta: float) -> void:
	var total := _tower.all_bodies().size()
	_info.text = "%s\nUyuyan: %d/%d   En büyük kayma: %.3f m" % [
		_info_static, _tower.sleeping_count(), total, _tower.max_drift()]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not (key and key.pressed and not key.echo):
		return
	match key.keycode:
		KEY_G:
			_area_guide.visible = not _area_guide.visible
		KEY_SPACE:
			_tower.wake_all()


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
	var a := _vec3(guide["min"])
	var b := _vec3(guide["max"])
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


static func _vec3(v: Variant) -> Vector3:
	var arr: Array = v
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
