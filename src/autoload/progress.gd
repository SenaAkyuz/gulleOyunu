extends Node
## Player progress + level rewards (docs/02 §4.1, docs/05 §2; Faz 2 Step 5).
## Saved in SaveManager.data: levels[id] = {stars, best_shots_left, cleared, jackpot}, unlocked_balls,
## flags (world bonuses already paid). Listens to EventBus only.
## Rewards (docs/05 formula, economy.json numbers):
##   stars:   first win = rewards.stars[s]; later = (better ? stars[s] - stars[best] : 0)
##            + round(stars[s] x replay_ratio); x boss_mult on boss levels
##   jackpot: core dropped in a WON attempt (also if it drops after the win): the level's first
##            jackpot = core_jackpot_gold, later ones x replay_ratio
##   crystal: materials.coin_on_break when a block breaks, at most rewards.crystal_coin_cap_per_level
##            per attempt, paid immediately
##   world:   world_complete_bonus when every level of a world is cleared, world_perfect_bonus when
##            all have 3 stars (each once)
## Unlocks: balls with unlock {type: level_cleared, level_id}; worlds by total stars
## (worlds.unlock_stars_required); levels in order (first level of an unlocked world is open,
## the next one opens when the previous is cleared).

const MAX_STARS := 3
const BOSS_ROLE := "boss"
const FLAG_WORLD_COMPLETE := "world_complete_%s"
const FLAG_WORLD_PERFECT := "world_perfect_%s"

## Level being played (EventBus.level_started); empty for dev levels that are not in game_data.
var current_level_id: String = ""

var _won: bool = false
var _core_dropped: bool = false
var _jackpot_paid: bool = false
var _crystal_coins: int = 0


func _ready() -> void:
	EventBus.level_started.connect(_on_level_started)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.core_dropped.connect(_on_core_dropped)
	EventBus.block_broken.connect(_on_block_broken)


# --- Queries ---

func level_result(id: String) -> Dictionary:
	return (SaveManager.data.get("levels", {}) as Dictionary).get(id, {})


func is_cleared(id: String) -> bool:
	return bool(level_result(id).get("cleared", false))


func stars_for(id: String) -> int:
	return int(level_result(id).get("stars", 0))


func total_stars() -> int:
	var n := 0
	for id: String in (SaveManager.data.get("levels", {}) as Dictionary):
		n += stars_for(id)
	return n


func is_world_unlocked(world_id: String) -> bool:
	var w := GameConfig.world(world_id)
	return not w.is_empty() and total_stars() >= int(w.get("unlock_stars_required", 0))


func is_level_unlocked(id: String) -> bool:
	var lv := _level_data(id)
	if lv.is_empty() or not is_world_unlocked(str(lv.get("world"))):
		return false
	var index := int(lv.get("index", 1))
	if index <= 1:
		return true
	return is_cleared(_level_id(str(lv.get("world")), index - 1))


func is_ball_unlocked(ball_id: String) -> bool:
	return (SaveManager.data.get("unlocked_balls", []) as Array).has(ball_id)


# --- Recording a win (also called directly by tests) ---

## Saves the result, pays star (+ jackpot if the core already fell) gold, unlocks, world bonuses.
## Returns the breakdown also sent with EventBus.level_rewarded.
func record_win(id: String, stars: int, shots_left: int, core_dropped: bool) -> Dictionary:
	var prev := level_result(id)
	var first := not bool(prev.get("cleared", false))
	var prev_stars := int(prev.get("stars", 0))
	var lv := _level_data(id)
	var worlds_before := _unlocked_world_ids()

	var star_gold := star_reward(stars, prev_stars, first, str(lv.get("role")) == BOSS_ROLE)
	var jackpot_gold := jackpot_reward(id) if core_dropped else 0

	var levels: Dictionary = SaveManager.data["levels"]
	levels[id] = {
		"stars": maxi(stars, prev_stars),
		"best_shots_left": maxi(shots_left, int(prev.get("best_shots_left", 0))),
		"cleared": true,
		"jackpot": bool(prev.get("jackpot", false)) or core_dropped,
	}
	if star_gold > 0:
		Economy.earn(star_gold, "yildiz:%s" % id)
	if jackpot_gold > 0:
		Economy.earn(jackpot_gold, "jackpot:%s" % id)
	var bonus_gold := _world_bonuses(_world_id_of(id))
	_unlock_balls(id)
	for w: String in _unlocked_world_ids():
		if not worlds_before.has(w):
			EventBus.world_unlocked.emit(w)
	SaveManager.request_save()

	var breakdown := {
		"stars": star_gold, "jackpot": jackpot_gold, "crystal": _crystal_coins, "bonus": bonus_gold,
		"total": star_gold + jackpot_gold + bonus_gold, "first_clear": first,
	}
	EventBus.level_rewarded.emit(id, breakdown)
	return breakdown


## Star gold for a win with `stars` when the best so far was `prev_stars` (docs/05 formula).
func star_reward(stars: int, prev_stars: int, first: bool, boss: bool) -> int:
	var r: Dictionary = GameConfig.economy()["rewards"]
	var gold := 0
	if first:
		gold = _stars_gold(stars)
	else:
		if stars > prev_stars:
			gold += _stars_gold(stars) - _stars_gold(prev_stars)
		gold += roundi(_stars_gold(stars) * float(r["replay_ratio"]))
	if boss:
		gold = roundi(gold * float(r["boss_mult"]))
	return gold


## Jackpot gold for this level: full the first time, x replay_ratio afterwards.
func jackpot_reward(id: String) -> int:
	var r: Dictionary = GameConfig.economy()["rewards"]
	var full := int(r["core_jackpot_gold"])
	if bool(level_result(id).get("jackpot", false)):
		return roundi(full * float(r["replay_ratio"]))
	return full


# --- Event handlers (one attempt = level_started .. next level_started) ---

func _on_level_started(level_id: String) -> void:
	current_level_id = level_id if GameConfig.level_ids().has(level_id) else ""
	_won = false
	_core_dropped = false
	_jackpot_paid = false
	_crystal_coins = 0


func _on_level_completed(stars: int, shots_left: int) -> void:
	if current_level_id.is_empty() or _won:
		return
	_won = true
	_jackpot_paid = _core_dropped
	record_win(current_level_id, stars, shots_left, _core_dropped)


## The core may fall after the win (continuous fire, K-023): pay the jackpot then.
func _on_core_dropped(_core: Node3D) -> void:
	_core_dropped = true
	if current_level_id.is_empty() or not _won or _jackpot_paid:
		return
	_jackpot_paid = true
	var gold := jackpot_reward(current_level_id)
	(SaveManager.data["levels"][current_level_id] as Dictionary)["jackpot"] = true
	if gold > 0:
		Economy.earn(gold, "jackpot:%s" % current_level_id)
	EventBus.level_rewarded.emit(current_level_id, {"stars": 0, "jackpot": gold, "crystal": 0,
			"bonus": 0, "total": gold, "first_clear": false})


func _on_block_broken(_block: Node3D, material_id: String) -> void:
	if current_level_id.is_empty():
		return
	var coin := int(GameConfig.material(material_id).get("coin_on_break", 0))
	var cap := int(GameConfig.economy()["rewards"]["crystal_coin_cap_per_level"])
	var pay := mini(coin, cap - _crystal_coins)
	if pay <= 0:
		return
	_crystal_coins += pay
	Economy.earn(pay, "kristal:%s" % current_level_id)


# --- Internals ---

## Level dictionary, or {} for ids without a file yet (does not record a GameConfig error).
func _level_data(id: String) -> Dictionary:
	return GameConfig.level(id) if GameConfig.level_ids().has(id) else {}


## World of a level: from its file, else from the id pattern wNN_lMM (worlds.index = NN).
func _world_id_of(id: String) -> String:
	var lv := _level_data(id)
	if not lv.is_empty():
		return str(lv.get("world"))
	if id.length() >= 3 and id.begins_with("w") and id.substr(1, 2).is_valid_int():
		var index := id.substr(1, 2).to_int()
		for w: Dictionary in GameConfig.worlds():
			if int(w.get("index", 0)) == index:
				return str(w["id"])
	return ""


func _stars_gold(stars: int) -> int:
	if stars <= 0:
		return 0
	return int((GameConfig.economy()["rewards"]["stars"] as Dictionary)[str(mini(stars, MAX_STARS))])


func _level_id(world_id: String, index: int) -> String:
	var w := GameConfig.world(world_id)
	return "w%02d_l%02d" % [int(w.get("index", 0)), index]


func _unlocked_world_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for w: Dictionary in GameConfig.worlds():
		if is_world_unlocked(str(w["id"])):
			out.append(str(w["id"]))
	return out


func _unlock_balls(cleared_id: String) -> void:
	var unlocked: Array = SaveManager.data["unlocked_balls"]
	for b: Dictionary in GameConfig.balls():
		var u: Dictionary = b.get("unlock", {})
		if str(u.get("type")) == "level_cleared" and str(u.get("level_id")) == cleared_id \
				and not unlocked.has(b["id"]):
			unlocked.append(b["id"])
			EventBus.ball_unlocked.emit(str(b["id"]))


## Pays world_complete / world_perfect once each. Returns the gold paid now.
func _world_bonuses(world_id: String) -> int:
	var w := GameConfig.world(world_id)
	if w.is_empty():
		return 0
	var count := int(w.get("level_count", 0))
	var cleared := 0
	var perfect := 0
	for i in range(1, count + 1):
		var id := _level_id(world_id, i)
		if is_cleared(id):
			cleared += 1
		if stars_for(id) >= MAX_STARS:
			perfect += 1
	var r: Dictionary = GameConfig.economy()["rewards"]
	var flags: Dictionary = SaveManager.data["flags"]
	var paid := 0
	if count > 0 and cleared == count and not flags.has(FLAG_WORLD_COMPLETE % world_id):
		flags[FLAG_WORLD_COMPLETE % world_id] = true
		paid += int(r["world_complete_bonus"])
		Economy.earn(int(r["world_complete_bonus"]), "dunya_bitti:%s" % world_id)
	if count > 0 and perfect == count and not flags.has(FLAG_WORLD_PERFECT % world_id):
		flags[FLAG_WORLD_PERFECT % world_id] = true
		paid += int(r["world_perfect_bonus"])
		Economy.earn(int(r["world_perfect_bonus"]), "dunya_mukemmel:%s" % world_id)
	return paid
