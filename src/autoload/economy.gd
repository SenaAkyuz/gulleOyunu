extends Node
## Gold balance (docs/02 §4.1, docs/05; Faz 2 Step 4). The balance lives in SaveManager.data.gold.
## earn(amount, reason) / spend(amount, reason) -> bool; spend never goes below zero.
## Every change emits EventBus.currency_changed and is logged with its reason (Analytics later).
## Gems are disabled (economy.currencies.gem.enabled = false), so only gold exists for now.

const GOLD := "gold"
## Recent transactions kept in memory for debugging (not saved, not a game rule).
const HISTORY_SIZE := 50

## [{ "amount": +/-int, "reason": String, "balance": int }], newest last.
var history: Array[Dictionary] = []


func _ready() -> void:
	SaveManager.loaded.connect(_on_save_loaded)


func balance() -> int:
	return int(SaveManager.data.get(GOLD, 0))


func can_afford(amount: int) -> bool:
	return amount >= 0 and balance() >= amount


## Adds gold. amount must be > 0. Returns false (and changes nothing) otherwise.
func earn(amount: int, reason: String) -> bool:
	if amount <= 0:
		push_error("Economy.earn: miktar pozitif olmalı (%d, %s)" % [amount, reason])
		return false
	_set_balance(balance() + amount, amount, reason)
	return true


## Removes gold if the player has enough. Returns false when it cannot afford it.
func spend(amount: int, reason: String) -> bool:
	if amount <= 0:
		push_error("Economy.spend: miktar pozitif olmalı (%d, %s)" % [amount, reason])
		return false
	if not can_afford(amount):
		return false
	_set_balance(balance() - amount, -amount, reason)
	return true


func _set_balance(value: int, delta: int, reason: String) -> void:
	SaveManager.data[GOLD] = value
	history.append({"amount": delta, "reason": reason, "balance": value})
	if history.size() > HISTORY_SIZE:
		history.pop_front()
	print("Economy: %+d altın (%s) → %d" % [delta, reason, value])
	EventBus.currency_changed.emit(GOLD, value)
	SaveManager.request_save()


func _on_save_loaded(_status: int) -> void:
	EventBus.currency_changed.emit(GOLD, balance())
