@tool
extends EditorPlugin
## Ordino level editor (Faz 3 Step 10, docs/03 §8.2, K-024): a dock on the left, next to the Scene tab. Heavy work runs
## in a headless background Godot (src/tools/sim/editor_cli.gd, candidates_cli.gd) because the
## editor runs no physics and no autoloads.

const DOCK := preload("res://addons/ordino_level_editor/dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = DOCK.new()
	_dock.name = "Ordino Bölüm"
	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)  # next to the Scene tab, easy to find
	print("Ordino Bölüm Editörü hazır")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
