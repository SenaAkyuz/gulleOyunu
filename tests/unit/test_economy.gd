extends GutTest
## Economy (src/autoload/economy.gd): gold earn / spend with reasons, never below zero.

const SaveSandbox = preload("res://tests/helpers/save_sandbox.gd")
var box := SaveSandbox.new()


func before_each() -> void:
	box.enter()


func after_all() -> void:
	box.exit()


func test_starts_with_start_amount() -> void:
	assert_eq(Economy.balance(), int(GameConfig.economy()["currencies"]["gold"]["start_amount"]))


func test_earn_adds_and_saves_in_data() -> void:
	var before := Economy.balance()
	assert_true(Economy.earn(35, "test"))
	assert_eq(Economy.balance(), before + 35)
	assert_eq(int(SaveManager.data["gold"]), before + 35)


func test_spend_with_enough_gold() -> void:
	SaveManager.data["gold"] = 100
	assert_true(Economy.spend(60, "test"))
	assert_eq(Economy.balance(), 40)


func test_spend_without_enough_gold_changes_nothing() -> void:
	SaveManager.data["gold"] = 50
	assert_false(Economy.spend(60, "test"))
	assert_eq(Economy.balance(), 50)


func test_zero_or_negative_amounts_are_rejected() -> void:
	SaveManager.data["gold"] = 50
	assert_false(Economy.earn(0, "test"))
	assert_false(Economy.earn(-5, "test"))
	assert_false(Economy.spend(-5, "test"))
	assert_eq(Economy.balance(), 50)
	assert_push_error_count(3, "her geçersiz miktar bir hata mesajı verir")


func test_change_emits_currency_changed() -> void:
	watch_signals(EventBus)
	Economy.earn(10, "test")
	assert_signal_emitted(EventBus, "currency_changed")


func test_history_records_reason() -> void:
	Economy.earn(7, "kristal")
	var last: Dictionary = Economy.history[Economy.history.size() - 1]
	assert_eq(last["reason"], "kristal")
	assert_eq(last["amount"], 7)


func test_float_balance_from_json_reads_as_int() -> void:
	SaveManager.data["gold"] = 120.0
	assert_eq(Economy.balance(), 120)
	assert_true(Economy.spend(20, "test"))
	assert_eq(Economy.balance(), 100)
