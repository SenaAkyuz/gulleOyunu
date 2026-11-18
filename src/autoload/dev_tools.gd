extends Node
## Developer helpers (debug builds only):
## - F12: save a screenshot to res://_screenshots/ (git-ignored, Godot-ignored)
## - command line "-- --auto-screenshot": save one screenshot shortly after start, then quit
##   (lets Claude check the framing without a human).

const SHOT_DIR := "res://_screenshots/"
const AUTO_SHOT_ARG := "--auto-screenshot"
## Frames to wait so the scene has rendered at least once with final camera/lighting.
const AUTO_SHOT_DELAY_FRAMES := 20


func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	if OS.get_cmdline_user_args().has(AUTO_SHOT_ARG):
		_auto_screenshot()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F12:
		save_screenshot()


func save_screenshot() -> String:
	var dir_abs := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var gdignore := dir_abs.path_join(".gdignore")
	if not FileAccess.file_exists(gdignore):
		FileAccess.open(gdignore, FileAccess.WRITE).close()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := dir_abs.path_join("shot_%s.png" % stamp)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err == OK:
		print("Ekran görüntüsü kaydedildi: ", path)
	else:
		push_error("Ekran görüntüsü kaydedilemedi: %s (%s)" % [path, error_string(err)])
	return path


func _auto_screenshot() -> void:
	for i in AUTO_SHOT_DELAY_FRAMES:
		await get_tree().process_frame
	save_screenshot()
	get_tree().quit()
