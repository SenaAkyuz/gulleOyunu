extends GutTest
## Inventory (src/autoload/inventory.gd): ball pieces, unlimited heavy ball, gifts, consumption.

const SaveSandbox = preload("res://tests/helpers/save_sandbox.gd")
var box := SaveSandbox.new()


func before_each() -> void:
	box.enter()


func after_all() -> void:
	box.exit()


func _gift(ball_id: String) -> int:
	return int(GameConfig.ball(ball_id)["gift_on_unlock"])


func test_heavy_is_unlimited() -> void:
	assert_true(Inventory.is_infinite("heavy"))
	assert_eq(Inventory.count("heavy"), Inventory.INFINITE)
	for i in 5:
		assert_true(Inventory.consume("heavy"))
	assert_eq(Inventory.count("heavy"), Inventory.INFINITE)


func test_locked_ball_counts_zero() -> void:
	assert_eq(Inventory.count("fire"), 0)
	assert_false(Inventory.has_ammo("fire"))
	assert_false(Inventory.consume("fire"))


func test_unlock_gives_gift() -> void:
	SaveManager.data["unlocked_balls"].append("fire")
	EventBus.ball_unlocked.emit("fire")
	assert_eq(Inventory.count("fire"), _gift("fire"))


func test_firing_uses_one_piece() -> void:
	SaveManager.data["unlocked_balls"].append("fire")
	EventBus.ball_unlocked.emit("fire")
	EventBus.ball_fired.emit("fire")
	assert_eq(Inventory.count("fire"), _gift("fire") - 1)


func test_cannot_go_below_zero() -> void:
	SaveManager.data["unlocked_balls"].append("saw")
	Inventory.grant("saw", 1)
	assert_true(Inventory.consume("saw"))
	assert_false(Inventory.consume("saw"))
	assert_eq(Inventory.count("saw"), 0)


func test_grant_rejects_bad_input() -> void:
	assert_false(Inventory.grant("fire", 0))
	assert_false(Inventory.grant("yok_boyle_top", 3))
	assert_push_error_count(2)


func test_progress_unlock_flows_into_inventory() -> void:
	var level_id := str(GameConfig.ball("fire")["unlock"]["level_id"])
	Progress.record_win(level_id, 1, 0, false)
	assert_eq(Inventory.count("fire"), _gift("fire"))


func test_change_emits_signal() -> void:
	SaveManager.data["unlocked_balls"].append("ice")
	watch_signals(EventBus)
	Inventory.grant("ice", 2)
	assert_signal_emitted_with_parameters(EventBus, "inventory_changed", ["ice", 2])
