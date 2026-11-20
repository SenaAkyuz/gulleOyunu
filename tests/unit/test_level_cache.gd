extends GutTest
## Disk cache of generated levels (Sena 2026-11-20, K-032): first N/B waits, later ones are instant;
## a change to the rules / generation code makes the old entry unreachable.

const DIR := "user://gut_level_cache/"
var _old_dir: String
var _old_use: bool


func before_all() -> void:
	_old_dir = LevelGenerator.cache_dir
	_old_use = LevelGenerator.use_disk_cache
	LevelGenerator.cache_dir = DIR
	LevelGenerator.use_disk_cache = true
	_clean()


func after_all() -> void:
	_clean()
	LevelGenerator.cache_dir = _old_dir
	LevelGenerator.use_disk_cache = _old_use
	LevelGenerator.clear_cache()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))


func test_second_open_comes_from_disk() -> void:
	LevelGenerator.clear_cache()
	var first: Dictionary = await LevelGenerator.resolve("w01_l02", self)
	var key := LevelGenerator.cache_key("akdeniz", 2, int(GameConfig.rule("generator.base_seed")), LevelGenerator.rules_hash())
	assert_true(FileAccess.file_exists(DIR + key + ".json"), "önbellek dosyası yazılmalı")
	LevelGenerator.clear_cache()  # = a new game session
	var started := Time.get_ticks_msec()
	var second: Dictionary = await LevelGenerator.resolve("w01_l02", self)
	assert_true(bool(second.get("from_disk_cache", false)), "ikinci açılış önbellekten")
	assert_lt(Time.get_ticks_msec() - started, 500, "önbellekten açılış anında olmalı")
	assert_eq(second["ok"], first["ok"])
	assert_eq(JSON.stringify(second["level"]["blocks"]), JSON.stringify(first["level"]["blocks"]))
	# The loaded level still builds and passes the static checks.
	assert_eq(LevelChecks.flatten(LevelChecks.static_problems(second["level"])).size(), 0)


func test_key_changes_with_rules() -> void:
	var a := LevelGenerator.cache_key("akdeniz", 2, 1000, "aaaa1111bbbb2222cccc")
	var b := LevelGenerator.cache_key("akdeniz", 2, 1000, "aaaa1111bbbb2222dddd")
	var c := LevelGenerator.cache_key("akdeniz", 2, 1000, "ffff1111bbbb2222cccc")
	assert_ne(a, c, "kural hash'i değişince anahtar değişir")
	assert_eq(a, b, "anahtar hash'in ilk 16 hanesini kullanır")
	assert_ne(LevelGenerator.cache_key("akdeniz", 2, 1001, "x"), LevelGenerator.cache_key("akdeniz", 2, 1000, "x"), "seed anahtarda")
	assert_eq(LevelGenerator.rules_hash().length(), 32, "MD5")
