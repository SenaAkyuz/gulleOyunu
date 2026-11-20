class_name LevelReferee
extends Node
## Level rules (docs/02 §6.6, K-018) with continuous fire (Faz 1 play-test feedback):
##   AIMING -> BALL_IN_FLIGHT -> COOLDOWN -> AIMING ...   (shots left)
##                            -> SETTLING -> EVALUATE -> WON | LOST   (last shot)
## - BALL_IN_FLIGHT starts on EventBus.ball_fired (one shot used). The ball's first contact
##   (EventBus.ball_hit) or its expiry ends it: with shots left the player may fire again after
##   rules.shots.refire_cooldown_sec (the tower is NOT waited for); after the last shot SETTLING
##   waits until every body rests (asleep or slower than rules.physics.settle_linear_velocity_threshold,
##   no ball alive) or rules.physics.settle_timeout_sec.
## - WIN is checked every tick and happens the moment the objective is met. The only objective is
##   clear_percent (K-018, K-030): cleared volume (or count) / total >= target; cleared = centre of mass
##   outside the platform (edge rule), or broken when rules.objective_defaults.broken_counts_as_cleared.
##   Core/joints excluded. The Golden Core never ends a level (K-030).
## - LOSS only in EVALUATE after the last shot settled (no automatic final clear).
## - Golden Core: checked every tick, also after the win; dropping it emits EventBus.core_dropped
##   (jackpot gold only, never affects stars or the result).
## - Stars (rules.stars, mode shots_left) from shots left at the win (= shots used).
## Talks to the rest of the game only through EventBus.

enum State { AIMING, BALL_IN_FLIGHT, COOLDOWN, SETTLING, EVALUATE, WON, LOST }

const STATE_NAMES := {
	State.AIMING: "AIMING", State.BALL_IN_FLIGHT: "BALL_IN_FLIGHT", State.COOLDOWN: "COOLDOWN",
	State.SETTLING: "SETTLING", State.EVALUATE: "EVALUATE", State.WON: "WON", State.LOST: "LOST",
}
const OBJ_CLEAR_PERCENT := "clear_percent"
const SUPPORTED_OBJECTIVES: PackedStringArray = [OBJ_CLEAR_PERCENT]
const STARS_MODE_SHOTS_LEFT := "shots_left"
const MEASURE_VOLUME := "volume"
## Only re-emit clear progress when it moved more than this (avoids per-tick signal spam).
const PROGRESS_EPSILON := 0.001

var state: State = State.AIMING
var objective_type: String = ""
var clear_target: float = 0.0
var clear_ratio: float = 0.0
var shots_total: int = 0
var shots_left: int = 0
var stars: int = 0
var core_dropped: bool = false

var _tower: TowerBuilder
var _platform: Platform
var _margin: float = 0.0
var _kill_y: float = 0.0
var _settle_timeout: float = 0.0
var _settle_threshold: float = 0.0
var _settle_elapsed: float = 0.0
var _measure_volume: bool = true
var _broken_counts: bool = true
var _last_ratio: float = -1.0
var _refire_cooldown: float = 0.0
var _cooldown_left: float = 0.0
var _balls_alive: int = 0


func setup(level: Dictionary, tower: TowerBuilder, platform: Platform) -> void:
	_tower = tower
	_platform = platform
	var edge_rule := str(GameConfig.rule("physics.edge_rule"))
	if edge_rule != EdgeRule.COM_OUTSIDE_PLATFORM:
		push_error("LevelReferee: desteklenmeyen edge_rule: " + edge_rule)
	_margin = float(GameConfig.rule("physics.edge_margin"))
	_kill_y = float(GameConfig.rule("physics.fall_kill_y"))
	_settle_timeout = float(GameConfig.rule("physics.settle_timeout_sec"))
	_settle_threshold = float(GameConfig.rule("physics.settle_linear_velocity_threshold"))
	_measure_volume = str(GameConfig.rule("objective_defaults.clear_measure")) == MEASURE_VOLUME
	_broken_counts = bool(GameConfig.rule("objective_defaults.broken_counts_as_cleared"))
	_refire_cooldown = float(GameConfig.rule("shots.refire_cooldown_sec"))

	var shots: Variant = level.get("shots", GameConfig.rule("shots.default_per_level"))
	shots_total = int(shots)
	shots_left = shots_total
	var objective: Dictionary = level.get("objective", {})
	objective_type = str(objective.get("type", GameConfig.rule("objective_defaults.type")))
	clear_target = float(objective.get("target", GameConfig.rule("objective_defaults.clear_percent_target")))
	if not SUPPORTED_OBJECTIVES.has(objective_type):
		push_error("LevelReferee: '%s' hedefi yok (K-030); clear_percent kullanılıyor" % objective_type)
		objective_type = OBJ_CLEAR_PERCENT

	EventBus.ball_fired.connect(_on_ball_fired)
	EventBus.ball_expired.connect(_on_ball_expired)
	EventBus.ball_hit.connect(_on_ball_hit)
	_announce_start.call_deferred(str(level.get("id", "")))


func is_aiming() -> bool:
	return state == State.AIMING


func state_name() -> String:
	return STATE_NAMES[state]


func fallen_block_count() -> int:
	var n := 0
	for b in _tower.blocks:
		if b.is_fallen:
			n += 1
	return n


func _announce_start(level_id: String) -> void:
	EventBus.level_started.emit(level_id)
	EventBus.shots_changed.emit(shots_left, shots_total)
	EventBus.referee_state_changed.emit(state_name())
	_update_progress(false)


func _on_ball_fired(_ball_id: String) -> void:
	if state != State.AIMING:
		return
	shots_left -= 1
	_balls_alive += 1
	EventBus.shots_changed.emit(shots_left, shots_total)
	_set_state(State.BALL_IN_FLIGHT)


func _on_ball_hit(_ball_id: String) -> void:
	if state == State.BALL_IN_FLIGHT:
		_ball_landed()


func _on_ball_expired(_ball_id: String) -> void:
	_balls_alive = maxi(0, _balls_alive - 1)
	if state == State.BALL_IN_FLIGHT:
		_ball_landed()


## The current ball touched something (or vanished): refire cooldown, or settle after the last shot.
func _ball_landed() -> void:
	if shots_left > 0:
		_cooldown_left = _refire_cooldown
		_set_state(State.COOLDOWN)
	else:
		_settle_elapsed = 0.0
		_set_state(State.SETTLING)


func _physics_process(delta: float) -> void:
	if _tower == null:
		return
	_check_cores()
	_mark_settled_blocks()
	_retire_lost_bodies()
	_update_progress(false)
	if state == State.WON or state == State.LOST:
		return
	if _objective_met():
		_win()
		return
	match state:
		State.COOLDOWN:
			_cooldown_left -= delta
			if _cooldown_left <= 0.0:
				_set_state(State.AIMING)
		State.SETTLING:
			_settle_elapsed += delta
			if (_all_settled() and _balls_alive == 0) or _settle_elapsed >= _settle_timeout:
				_evaluate()


func _check_cores() -> void:
	for c in _tower.cores:
		if not c.is_fallen and _is_out(c):
			c.set_fallen(true)
			if not core_dropped:
				core_dropped = true
				EventBus.core_dropped.emit(c)


## Settled blocks get their (grey) verdict early; the final verdict is made in _evaluate().
func _mark_settled_blocks() -> void:
	for b in _tower.blocks:
		if not b.is_broken and (b.sleeping or b.world_center_of_mass().y < _kill_y):
			b.set_fallen(_is_out(b))


## Below fall_kill_y: stop simulating and hide (stands in for the docs' KillZone, keeps the body budget low).
func _retire_lost_bodies() -> void:
	for body in _tower.all_bodies():
		if body.visible and body.world_center_of_mass().y < _kill_y:
			body.set_fallen(true)
			body.visible = false
			body.set_deferred("freeze", true)


func _all_settled() -> bool:
	for body in _tower.all_bodies():
		if not body.visible or body.is_broken:
			continue
		if not body.sleeping and body.linear_velocity.length() >= _settle_threshold:
			return false
	return true


## Last shot settled: final verdicts, then WON (met at the very end) or LOST.
func _evaluate() -> void:
	_set_state(State.EVALUATE)
	for b in _tower.blocks:
		if not b.is_broken:
			b.set_fallen(_is_out(b))
	_update_progress(true)
	if _objective_met():
		_win()
	else:
		_set_state(State.LOST)
		EventBus.level_failed.emit()


func _win() -> void:
	stars = _stars_for(shots_left)
	_set_state(State.WON)
	EventBus.level_completed.emit(stars, shots_left)


func _objective_met() -> bool:
	return clear_ratio >= clear_target


## final = true uses the settled verdicts only; otherwise blocks still moving are judged live.
func _update_progress(final: bool) -> void:
	var total := 0.0
	var cleared := 0.0
	for b in _tower.blocks:
		var weight := b.volume if _measure_volume else 1.0
		total += weight
		var gone := b.is_fallen if final else (b.is_fallen or (not b.is_broken and _is_out(b)))
		if b.is_broken and _broken_counts:
			gone = true
		if gone:
			cleared += weight
	clear_ratio = cleared / total if total > 0.0 else 0.0
	if final or absf(clear_ratio - _last_ratio) > PROGRESS_EPSILON:
		_last_ratio = clear_ratio
		EventBus.clear_progress_changed.emit(clear_ratio, clear_target)


## rules.stars, mode shots_left: 3 stars if shots_left >= shots - offset3, 2 if >= shots - offset2, else 1.
func _stars_for(left: int) -> int:
	var mode := str(GameConfig.rule("stars.mode"))
	if mode != STARS_MODE_SHOTS_LEFT:
		push_warning("LevelReferee: stars.mode '%s' Faz 1'de yok; shots_left kullanılıyor" % mode)
	var three := shots_total - int(GameConfig.rule("stars.three_star_min_shots_left_offset"))
	var two := shots_total - int(GameConfig.rule("stars.two_star_min_shots_left_offset"))
	if left >= three:
		return 3
	if left >= two:
		return 2
	return 1


func _is_out(body: Block) -> bool:
	return EdgeRule.is_fallen(body.world_center_of_mass(), _platform.half_width,
			_platform.half_depth, _margin, _kill_y)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	EventBus.referee_state_changed.emit(state_name())
