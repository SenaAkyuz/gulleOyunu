extends GutTest
## SaveManager (src/autoload/save_manager.gd): versioned, atomic, recovers from corrupt files.
## Uses throw-away files in user://gut_save_test/ and restores the real paths afterwards.

const DIR := "user://gut_save_test/"
const PATH := DIR + "save.json"
const BACKUP := DIR + "save.bak.json"

var _real_path: String
var _real_backup: String
var _real_data: Dictionary


func before_all() -> void:
	_real_path = SaveManager.save_path
	_real_backup = SaveManager.backup_path
	_real_data = SaveManager.data.duplicate(true)


func after_all() -> void:
	SaveManager.save_path = _real_path
	SaveManager.backup_path = _real_backup
	SaveManager.data = _real_data
	SaveManager.read_only = false
	_clean()


func before_each() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	SaveManager.save_path = PATH
	SaveManager.backup_path = BACKUP


func _clean() -> void:
	for f in ["save.json", "save.bak.json", "save.json.tmp", "save.json.corrupt"]:
		if FileAccess.file_exists(DIR + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_new_player_gets_defaults_and_file() -> void:
	assert_eq(SaveManager.load_game(), SaveManager.LoadStatus.NEW)
	var start_gold := int(GameConfig.economy()["currencies"]["gold"]["start_amount"])
	assert_eq(int(SaveManager.data["gold"]), start_gold)
	assert_eq(SaveManager.data["unlocked_balls"], [GameConfig.starting_ball_id()])
	assert_true(FileAccess.file_exists(PATH), "yeni kayıt diske yazıldı")


func test_save_and_load_roundtrip() -> void:
	SaveManager.load_game()
	SaveManager.data["gold"] = 250
	SaveManager.data["levels"]["w01_l01"] = {"stars": 3}
	assert_eq(SaveManager.save_game(), OK)
	SaveManager.data = {}
	assert_eq(SaveManager.load_game(), SaveManager.LoadStatus.LOADED)
	assert_eq(int(SaveManager.data["gold"]), 250)
	assert_eq(int(SaveManager.data["levels"]["w01_l01"]["stars"]), 3)


func test_save_leaves_no_tmp_and_keeps_backup() -> void:
	SaveManager.load_game()
	SaveManager.data["gold"] = 111
	SaveManager.save_game()
	SaveManager.data["gold"] = 222
	SaveManager.save_game()
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
	assert_eq(int(_read(BACKUP)["gold"]), 111, "yedek bir önceki sağlam kayıt")
	assert_eq(int(_read(PATH)["gold"]), 222)


func test_corrupt_file_recovers_from_backup() -> void:
	_write(BACKUP, JSON.stringify({"save_version": 1, "gold": 77}))
	_write(PATH, "{ bozuk json")
	assert_eq(SaveManager.load_game(), SaveManager.LoadStatus.RECOVERED_BACKUP)
	assert_eq(int(SaveManager.data["gold"]), 77)
	assert_true(FileAccess.file_exists(PATH + ".corrupt"), "bozuk dosya incelemek için saklandı")


func test_corrupt_file_and_no_backup_resets() -> void:
	_write(PATH, "çöp")
	assert_eq(SaveManager.load_game(), SaveManager.LoadStatus.RESET_CORRUPT)
	assert_eq(int(SaveManager.data["save_version"]), SaveManager.CURRENT_VERSION)


func test_v0_save_is_migrated() -> void:
	_write(PATH, JSON.stringify({"gold": 55.0, "levels": {}}))
	assert_eq(SaveManager.load_game(), SaveManager.LoadStatus.MIGRATED)
	assert_eq(int(SaveManager.data["save_version"]), 1)
	assert_eq(SaveManager.data["gold"], 55)
	assert_true(SaveManager.data.has("settings"), "eksik alan varsayılanla dolduruldu")
	assert_eq(int(_read(PATH)["save_version"]), 1, "yükseltilmiş kayıt diske yazıldı")


func test_newer_version_is_never_overwritten() -> void:
	var future := JSON.stringify({"save_version": 99, "gold": 9999})
	_write(PATH, future)
	assert_eq(SaveManager.load_game(), SaveManager.LoadStatus.NEWER_VERSION)
	assert_true(SaveManager.read_only)
	SaveManager.data["gold"] = 1
	assert_ne(SaveManager.save_game(), OK)
	assert_eq(FileAccess.get_file_as_string(PATH), future, "dosyaya dokunulmadı")


func test_missing_settings_key_is_filled() -> void:
	_write(PATH, JSON.stringify({"save_version": 1, "gold": 5, "settings": {"sfx": 0.2}}))
	SaveManager.load_game()
	assert_almost_eq(float(SaveManager.data["settings"]["sfx"]), 0.2, 0.0001, "oyuncunun ayarı korunur")
	assert_true(SaveManager.data["settings"].has("music"))
	assert_true(SaveManager.data["settings"].has("haptics"))
