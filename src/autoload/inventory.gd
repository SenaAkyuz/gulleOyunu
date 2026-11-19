extends Node
## Ball counts (docs/02 §4.1, docs/05; Faz 2 Step 6). Saved in SaveManager.data.inventory {ball_id: n}.
## - A ball with balls.json gift_on_unlock = -1 (heavy) is unlimited once unlocked.
## - Locked balls count 0. When Progress unlocks a ball (EventBus.ball_unlocked) the player gets
##   gift_on_unlock pieces. Every EventBus.ball_fired uses one piece.
## Buying packs (price_gold / pack_size) comes with the shop in Faz 6.

const INFINITE := -1


func _ready() -> void:
	EventBus.ball_unlocked.connect(_on_ball_unlocked)
	EventBus.ball_fired.connect(_on_ball_fired)


func is_infinite(ball_id: String) -> bool:
	return int(GameConfig.ball(ball_id).get("gift_on_unlock", 0)) == INFINITE and Progress.is_ball_unlocked(ball_id)


## Pieces owned; INFINITE (-1) for unlimited balls, 0 for locked ones.
func count(ball_id: String) -> int:
	if not Progress.is_ball_unlocked(ball_id):
		return 0
	if is_infinite(ball_id):
		return INFINITE
	return int(_inv().get(ball_id, 0))


func has_ammo(ball_id: String) -> bool:
	return is_infinite(ball_id) or count(ball_id) > 0


## Uses one piece. Returns false if none left (unlimited balls always succeed).
func consume(ball_id: String) -> bool:
	if is_infinite(ball_id):
		return true
	var n := count(ball_id)
	if n <= 0:
		return false
	_store(ball_id, n - 1)
	return true


## Adds n pieces (n > 0). Unlimited balls are unaffected. Works for locked balls too
## (e.g. a free_balls gift before the unlock).
func grant(ball_id: String, n: int) -> bool:
	if n <= 0 or GameConfig.ball(ball_id).is_empty():
		push_error("Inventory.grant: geçersiz top/adet (%s, %d)" % [ball_id, n])
		return false
	if is_infinite(ball_id):
		return true
	_store(ball_id, int(_inv().get(ball_id, 0)) + n)
	return true


func _on_ball_unlocked(ball_id: String) -> void:
	var gift := int(GameConfig.ball(ball_id).get("gift_on_unlock", 0))
	if gift > 0:
		grant(ball_id, gift)


func _on_ball_fired(ball_id: String) -> void:
	consume(ball_id)


func _inv() -> Dictionary:
	if not (SaveManager.data.get("inventory") is Dictionary):
		SaveManager.data["inventory"] = {}
	return SaveManager.data["inventory"]


func _store(ball_id: String, n: int) -> void:
	_inv()[ball_id] = n
	EventBus.inventory_changed.emit(ball_id, n)
	SaveManager.request_save()
