extends GutTest
## HUD (src/ui/hud): gold balance, best stars, gold earned under the win banner, jackpot amount.

const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const SaveSandbox = preload("res://tests/helpers/save_sandbox.gd")

var box := SaveSandbox.new()
var hud: Hud


func before_each() -> void:
	box.enter()
	Progress._on_level_started("")
	hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)


func after_all() -> void:
	box.exit()


func test_gold_label_follows_balance() -> void:
	assert_eq(hud._gold.text, "%d ALTIN" % Economy.balance())
	Economy.earn(7, "test")
	assert_eq(hud._gold.text, "%d ALTIN" % Economy.balance())


func test_best_stars_in_level_label() -> void:
	hud.setup(1, "clear_percent", 2)
	assert_eq(hud._level_label.text, "BÖLÜM 1  ★★☆")
	hud.setup(1, "clear_percent", 0)
	assert_eq(hud._level_label.text, "BÖLÜM 1")


func test_win_banner_shows_gold_earned() -> void:
	EventBus.level_started.emit("w01_l01")
	EventBus.level_completed.emit(3, 2)
	var stars_gold := int(GameConfig.economy()["rewards"]["stars"]["3"])
	assert_true(hud._banner.visible)
	assert_string_contains(hud._sub_banner.text, "+%d altın" % stars_gold)


func test_late_jackpot_shows_paid_amount() -> void:
	hud.setup(1, "clear_percent")
	EventBus.level_started.emit("w01_l01")
	EventBus.level_completed.emit(3, 2)
	EventBus.core_dropped.emit(null)
	var jackpot := int(GameConfig.economy()["rewards"]["core_jackpot_gold"])
	assert_true(hud._jackpot.visible)
	assert_eq(hud._jackpot.text, "JACKPOT!\n+%d altın" % jackpot)
