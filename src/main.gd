extends Node
## Phase 1 entry point: if GameConfig loaded game_data correctly, go straight to the level;
## otherwise stay here and show the errors in red.

const LEVEL_SCENE := "res://src/gameplay/level/level.tscn"

@onready var _status: Label = $Status


func _ready() -> void:
	if GameConfig.is_valid():
		_status.text = "GameConfig OK\n" + GameConfig.summary()
		_status.add_theme_color_override("font_color", Color.PALE_GREEN)
		get_tree().change_scene_to_file.call_deferred(LEVEL_SCENE)
	else:
		_status.text = "GameConfig HATA:\n" + "\n".join(GameConfig.errors)
		_status.add_theme_color_override("font_color", Color.TOMATO)
