extends GutTest
## Progress (src/autoload/progress.gd): results, rewards (docs/05 formula), unlocks.
## Expected gold is computed from economy.json, so retuning numbers (Faz 6) keeps tests valid.

const SaveSandbox = preload("res://tests/helpers/save_sandbox.gd")
var box := SaveSandbox.new()
var R: Dictionary


func before_each() -> void:
	box.enter()
	R = GameConfig.economy()["rewards"]
	Progress._on_level_started("")


func after_all() -> void:
	box.exit()


func _stars(s: int) -> int:
	return int(R["stars"][str(s)])


func _ratio(x: int) -> int:
	return roundi(x * float(R["replay_ratio"]))


func test_first_win_pays_full_star_reward() -> void:
	var before := Economy.balance()
	var b := Progress.record_win("w01_l01", 3, 2, false)
	assert_eq(b["stars"], _stars(3))
	assert_true(b["first_clear"])
	assert_eq(Economy.balance(), before + _stars(3))


func test_same_result_replay_pays_ratio() -> void:
	Progress.record_win("w01_l01", 3, 2, false)
	assert_eq(Progress.record_win("w01_l01", 3, 2, false)["stars"], _ratio(_stars(3)))


func test_upgrade_pays_difference_plus_replay() -> void:
	Progress.record_win("w01_l01", 2, 1, false)
	var b := Progress.record_win("w01_l01", 3, 2, false)
	assert_eq(b["stars"], _stars(3) - _stars(2) + _ratio(_stars(3)))


func test_worse_replay_keeps_best_stars() -> void:
	Progress.record_win("w01_l01", 3, 2, false)
	var b := Progress.record_win("w01_l01", 1, 0, false)
	assert_eq(b["stars"], _ratio(_stars(1)))
	assert_eq(Progress.stars_for("w01_l01"), 3)
	assert_eq(int(Progress.level_result("w01_l01")["best_shots_left"]), 2)


func test_boss_multiplier() -> void:
	assert_eq(Progress.star_reward(3, 0, true, true), roundi(_stars(3) * float(R["boss_mult"])))


func test_jackpot_full_then_ratio() -> void:
	var first := Progress.record_win("w01_l01", 3, 2, true)
	assert_eq(first["jackpot"], int(R["core_jackpot_gold"]))
	var again := Progress.record_win("w01_l01", 3, 2, true)
	assert_eq(again["jackpot"], _ratio(int(R["core_jackpot_gold"])))


func test_core_before_win_is_in_the_breakdown() -> void:
	watch_signals(EventBus)
	EventBus.level_started.emit("w01_l01")
	EventBus.core_dropped.emit(null)
	EventBus.level_completed.emit(3, 2)
	var params: Array = get_signal_parameters(EventBus, "level_rewarded")
	assert_eq(params[1]["jackpot"], int(R["core_jackpot_gold"]))


func test_core_after_win_pays_jackpot_once() -> void:
	EventBus.level_started.emit("w01_l01")
	EventBus.level_completed.emit(3, 2)
	var before := Economy.balance()
	EventBus.core_dropped.emit(null)
	EventBus.core_dropped.emit(null)
	assert_eq(Economy.balance(), before + int(R["core_jackpot_gold"]))
	assert_true(Progress.level_result("w01_l01")["jackpot"])


func test_crystal_coins_are_capped_per_attempt() -> void:
	EventBus.level_started.emit("w01_l01")
	var before := Economy.balance()
	for i in 30:
		EventBus.block_broken.emit(null, "crystal_amber")
	EventBus.block_broken.emit(null, "stone")
	assert_eq(Economy.balance(), before + int(R["crystal_coin_cap_per_level"]))
	EventBus.level_started.emit("w01_l01")
	EventBus.block_broken.emit(null, "crystal_purple")
	assert_eq(Economy.balance(), before + int(R["crystal_coin_cap_per_level"])
			+ int(GameConfig.material("crystal_purple")["coin_on_break"]), "yeni deneme yeni tavan")


func test_dev_levels_pay_nothing() -> void:
	EventBus.level_started.emit("dev_stress")
	var before := Economy.balance()
	EventBus.block_broken.emit(null, "crystal_amber")
	EventBus.level_completed.emit(3, 2)
	assert_eq(Economy.balance(), before)
	assert_false(Progress.is_cleared("dev_stress"))


func test_clearing_unlock_level_unlocks_ball() -> void:
	var fire: Dictionary = GameConfig.ball("fire")
	var unlock_level := str(fire["unlock"]["level_id"])
	watch_signals(EventBus)
	assert_false(Progress.is_ball_unlocked("fire"))
	Progress.record_win(unlock_level, 1, 0, false)
	assert_true(Progress.is_ball_unlocked("fire"))
	assert_signal_emitted_with_parameters(EventBus, "ball_unlocked", ["fire"])
	assert_eq(GameConfig.errors.size(), 0, "dosyası olmayan bölüm GameConfig hatası üretmez")


func test_world_unlocks_with_stars() -> void:
	var korsan := GameConfig.world("korsan")
	assert_false(Progress.is_world_unlocked("korsan"))
	var need := int(korsan["unlock_stars_required"])
	for i in range(1, ceili(need / 3.0) + 1):
		SaveManager.data["levels"]["w01_l%02d" % i] = {"stars": 3, "cleared": true}
	assert_true(Progress.is_world_unlocked("korsan"))


func test_levels_open_in_order() -> void:
	assert_true(Progress.is_level_unlocked("w01_l01"))
	assert_false(Progress.is_level_unlocked("w01_l03"))
	SaveManager.data["levels"]["w01_l02"] = {"stars": 1, "cleared": true}
	assert_true(Progress.is_level_unlocked("w01_l03"))


func test_world_complete_and_perfect_bonus_once() -> void:
	var count := int(GameConfig.world("akdeniz")["level_count"])
	for i in range(1, count):
		SaveManager.data["levels"]["w01_l%02d" % i] = {"stars": 3, "cleared": true}
	var last := "w01_l%02d" % count
	var b := Progress.record_win(last, 3, 2, false)
	assert_eq(b["bonus"], int(R["world_complete_bonus"]) + int(R["world_perfect_bonus"]))
	assert_eq(Progress.record_win(last, 3, 2, false)["bonus"], 0, "bonus bir kez")
