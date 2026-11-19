extends GutTest
## GameConfig (autoload): loads every game_data JSON, strips "_" doc keys, dotted rule lookup.


func test_loaded_without_errors() -> void:
	assert_true(GameConfig.is_valid(), "errors: %s" % [GameConfig.errors])


func test_dotted_rule_lookup() -> void:
	assert_eq(typeof(GameConfig.rule("physics.gravity")), TYPE_FLOAT)
	assert_null(GameConfig.rule("physics.does_not_exist"))


func test_doc_keys_are_stripped() -> void:
	assert_false((GameConfig.rule("aim") as Dictionary).has("_doc_mode"))


func test_starting_ball_is_heavy() -> void:
	assert_eq(GameConfig.starting_ball_id(), "heavy")


func test_start_level_exists() -> void:
	var id := str(GameConfig.rule("dev.start_level_id"))
	assert_false(GameConfig.level(id).is_empty())
