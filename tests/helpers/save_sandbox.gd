extends RefCounted
## Points SaveManager at throw-away files for a test script and restores the real save afterwards,
## so tests never touch the player's user://save.json.
## Usage: var box := SaveSandbox.new(); box.enter() in before_all / before_each; box.exit() in after_all.

const DIR := "user://gut_sandbox/"

var _path: String
var _backup: String
var _data: Dictionary


func enter() -> void:
	SaveManager.cancel_pending_save()
	if _path.is_empty():
		_path = SaveManager.save_path
		_backup = SaveManager.backup_path
		_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	SaveManager.save_path = DIR + "save.json"
	SaveManager.backup_path = DIR + "save.bak.json"
	SaveManager.read_only = false
	SaveManager.data = SaveManager.default_data()


func exit() -> void:
	SaveManager.cancel_pending_save()
	SaveManager.save_path = _path
	SaveManager.backup_path = _backup
	SaveManager.data = _data
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
