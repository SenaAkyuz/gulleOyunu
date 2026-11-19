extends GutTest
## Faz 2 "done" check (docs/06): win L01 -> gold + stars saved; quit/reopen keeps them.
## Plays the level flow through EventBus exactly as the referee does, lets the coalesced save
## hit the disk, wipes memory, loads the file again (= reopening the game) and compares.

const SaveSandbox = preload("res://tests/helpers/save_sandbox.gd")
const LEVEL := "w01_l01"

var box := SaveSandbox.new()


func before_each() -> void:
	box.enter()
	Progress._on_level_started("")


func after_all() -> void:
	box.exit()


func _win(stars: int, shots_left: int) -> void:
	EventBus.level_started.emit(LEVEL)
	EventBus.level_completed.emit(stars, shots_left)
	await wait_process_frames(2)  # request_save() writes at the end of the frame


func _reopen() -> void:
	SaveManager.data = {}
	SaveManager.load_game()


func test_win_survives_reopen() -> void:
	var start := Economy.balance()
	await _win(3, 2)
	var gold := Economy.balance()
	assert_gt(gold, start, "kazanınca altın artmalı")
	assert_true(FileAccess.file_exists(SaveManager.save_path), "kayıt diske yazılmalı")

	_reopen()
	assert_eq(SaveManager.load_status, SaveManager.LoadStatus.LOADED)
	assert_eq(Economy.balance(), gold)
	assert_eq(Progress.stars_for(LEVEL), 3)
	assert_true(Progress.is_cleared(LEVEL))
	assert_eq(int(Progress.level_result(LEVEL)["best_shots_left"]), 2)


func test_replay_after_reopen_pays_replay_ratio() -> void:
	await _win(3, 2)
	_reopen()
	var before := Economy.balance()
	await _win(3, 2)
	var r: Dictionary = GameConfig.economy()["rewards"]
	var expected := roundi(int(r["stars"]["3"]) * float(r["replay_ratio"]))
	assert_eq(Economy.balance() - before, expected, "kapat-aç sonrası ilk ödül tekrar ödenmemeli")


func test_reset_clears_progress_on_disk() -> void:
	await _win(2, 1)
	SaveManager.reset()
	_reopen()
	assert_eq(Progress.stars_for(LEVEL), 0)
	assert_eq(Economy.balance(), int(GameConfig.economy()["currencies"]["gold"]["start_amount"]))
