extends Node
## Temporary Phase 1 start screen: shows whether GameConfig loaded game_data correctly.

@onready var _status: Label = $Status


func _ready() -> void:
	if GameConfig.is_valid():
		_status.text = "GameConfig OK\n" + GameConfig.summary()
		_status.add_theme_color_override("font_color", Color.PALE_GREEN)
	else:
		_status.text = "GameConfig HATA:\n" + "\n".join(GameConfig.errors)
		_status.add_theme_color_override("font_color", Color.TOMATO)
