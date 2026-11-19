extends GutTest
## ConfigValidator (src/core/config_validator.gd): cross-file references in game_data.
## Each test copies the real data, breaks ONE thing and expects a matching Turkish error.

var data: Dictionary


func before_each() -> void:
	var levels: Dictionary = {}
	for id in GameConfig.level_ids():
		levels[id] = GameConfig.level(id).duplicate(true)
	data = {
		"rules": GameConfig._rules.duplicate(true),
		"materials": GameConfig._materials.duplicate(true),
		"shapes": GameConfig._shapes.duplicate(true),
		"balls": GameConfig._balls.duplicate(true),
		"worlds": GameConfig._worlds.duplicate(true),
		"economy": GameConfig._economy.duplicate(true),
		"levels": levels,
	}


func _errors() -> PackedStringArray:
	return ConfigValidator.new().validate(data).errors


func _assert_error(fragment: String) -> void:
	var errs := _errors()
	var found := false
	for e in errs:
		if e.contains(fragment):
			found = true
	assert_true(found, "beklenen hata '%s' yok; gelenler: %s" % [fragment, errs])


func test_real_data_has_no_errors() -> void:
	assert_eq(_errors().size(), 0, str(_errors()))


func test_level_block_with_unknown_material() -> void:
	data["levels"]["w01_l01"]["blocks"][0]["mat"] = "granit"
	_assert_error("malzemesi 'granit' materials.json'da yok")


func test_level_block_with_unknown_shape() -> void:
	data["levels"]["w01_l01"]["blocks"][0]["shape"] = "piramit"
	_assert_error("şekli 'piramit' shapes.json'da yok")


func test_keystone_must_exist() -> void:
	data["levels"]["w01_l01"]["keystones"] = ["b99"]
	_assert_error("keystone 'b99' blok listesinde yok")


func test_tutorial_target_must_exist() -> void:
	data["levels"]["w01_l01"]["tutorial"]["target_block"] = "b99"
	_assert_error("tutorial.target_block 'b99'")


func test_camera_override_unknown_key() -> void:
	data["levels"]["w01_l01"]["camera_override"]["zoom"] = 2
	_assert_error("camera_override.zoom")


func test_duplicate_block_id() -> void:
	data["levels"]["w01_l01"]["blocks"][1]["id"] = "b01"
	_assert_error("tekrar eden blok id 'b01'")


func test_world_palette_unknown_material() -> void:
	data["worlds"]["akdeniz"]["palette"]["mermer"] = 0.1
	_assert_error("worlds.akdeniz.palette: 'mermer'")


func test_ball_damage_mult_unknown_material() -> void:
	data["balls"]["heavy"]["damage_mult"]["mermer"] = 1.0
	_assert_error("balls.heavy.damage_mult: 'mermer'")


func test_material_needs_density() -> void:
	data["materials"]["stone"].erase("density")
	_assert_error("materials.stone: 'density' sayı olmalı")


func test_economy_stars_order() -> void:
	data["economy"]["rewards"]["stars"]["3"] = 5
	_assert_error("economy.rewards.stars: 1 ≤ 2 ≤ 3")


func test_economy_gold_start() -> void:
	data["economy"]["currencies"]["gold"]["start_amount"] = -10
	_assert_error("economy.currencies.gold.start_amount")


func test_start_level_must_exist() -> void:
	data["rules"]["dev"]["start_level_id"] = "w09_l99"
	_assert_error("start_level_id 'w09_l99'")


func test_drop_core_needs_cores_when_baked() -> void:
	data["levels"]["w01_l01"]["objective"] = {"type": "drop_core"}
	data["levels"]["w01_l01"]["cores"] = []
	_assert_error("drop_core hedefi ama cores boş")


func test_missing_behavior_is_only_a_warning() -> void:
	var v := ConfigValidator.new().validate(data)
	var fire_warned := false
	for w in v.warnings:
		if w.contains("balls.fire"):
			fire_warned = true
	assert_true(fire_warned)
	assert_eq(v.errors.size(), 0)
