class_name SlowMo
extends Node
## Golden Core slow motion (docs/07 §3), only if rules.feel.slowmo_enabled: when the core leaves the platform,
## Engine.time_scale = rules.feel.final_slowmo_scale for final_slowmo_duration_sec (real time).
## Listens to EventBus only. Always restores normal time when the level is left (e.g. R restart).
## Uses a child Timer (freed with this node) so a restart mid-slowmo leaves nothing pending.

const NORMAL_TIME_SCALE := 1.0

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.ignore_time_scale = true
	_timer.timeout.connect(_end)
	add_child(_timer)
	EventBus.core_dropped.connect(_on_core_dropped)


func _exit_tree() -> void:
	Engine.time_scale = NORMAL_TIME_SCALE


func _on_core_dropped(_core: Node3D) -> void:
	if not bool(GameConfig.rule("feel.slowmo_enabled")) or not _timer.is_stopped():
		return
	Engine.time_scale = float(GameConfig.rule("feel.final_slowmo_scale"))
	_timer.start(float(GameConfig.rule("feel.final_slowmo_duration_sec")))


func _end() -> void:
	Engine.time_scale = NORMAL_TIME_SCALE
