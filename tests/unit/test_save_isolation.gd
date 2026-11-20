extends GutTest
## Sena 2026-11-20: tests and simulations must never write the player's save.
## Every GUT / command-line run uses rules.save.test_file instead of rules.save.file.


func test_test_runs_use_the_test_save() -> void:
	assert_true(SaveManager.is_test_run(), "GUT koşusu test koşusu sayılmalı")
	var real := str(GameConfig.rule("save.file"))
	var test := str(GameConfig.rule("save.test_file"))
	assert_ne(real, test)
	# SaveSandbox tests swap paths temporarily; the autoload's own start-up path must be the test one.
	var box_free_path := SaveManager.save_path
	assert_true(box_free_path == test or box_free_path.begins_with("user://gut"), "kayıt yolu test yolu olmalı: " + box_free_path)
	assert_ne(box_free_path, real, "gerçek kayda asla yazılmamalı")


func test_writing_does_not_touch_the_real_save() -> void:
	var real_abs := ProjectSettings.globalize_path(str(GameConfig.rule("save.file")))
	var before := FileAccess.get_modified_time(real_abs) if FileAccess.file_exists(real_abs) else 0
	var text_before := FileAccess.get_file_as_string(real_abs) if FileAccess.file_exists(real_abs) else ""
	Economy.earn(3, "test:save_isolation")
	SaveManager.save_game()
	assert_eq(FileAccess.get_file_as_string(real_abs) if FileAccess.file_exists(real_abs) else "", text_before, "gerçek kayıt içeriği değişmemeli")
	if before != 0:
		assert_eq(FileAccess.get_modified_time(real_abs), before, "gerçek kayıt dosyası yazılmamalı")
	Economy.spend(3, "test:save_isolation")
	SaveManager.save_game()
