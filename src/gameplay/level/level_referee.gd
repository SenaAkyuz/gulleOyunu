class_name LevelReferee
extends Node
## Applies the edge rule (docs/02 §2, §6.6).
## Step 5: the core is checked every physics tick (drop -> EventBus.core_dropped, immediately);
## blocks are judged once they settle (asleep) or drop below fall_kill_y.
## Step 9 turns this into the AIMING -> BALL_IN_FLIGHT -> SETTLING -> EVALUATE state machine.

var core_dropped: bool = false

var _tower: TowerBuilder
var _platform: Platform
var _margin: float = 0.0
var _kill_y: float = 0.0


func setup(tower: TowerBuilder, platform: Platform) -> void:
	_tower = tower
	_platform = platform
	var rule := str(GameConfig.rule("physics.edge_rule"))
	if rule != EdgeRule.COM_OUTSIDE_PLATFORM:
		push_error("LevelReferee: desteklenmeyen edge_rule: " + rule)
	_margin = float(GameConfig.rule("physics.edge_margin"))
	_kill_y = float(GameConfig.rule("physics.fall_kill_y"))


func fallen_block_count() -> int:
	var n := 0
	for b in _tower.blocks:
		if b.is_fallen:
			n += 1
	return n


func _physics_process(_delta: float) -> void:
	if _tower == null:
		return
	for c in _tower.cores:
		if not c.is_fallen and _check(c):
			c.set_fallen(true)
			if not core_dropped:
				core_dropped = true
				EventBus.core_dropped.emit(c)
	for b in _tower.blocks:
		# A block's verdict is only final once it has settled (or left the world).
		if b.sleeping or b.world_center_of_mass().y < _kill_y:
			b.set_fallen(_check(b))
	for body in _tower.all_bodies():
		if body.visible and body.world_center_of_mass().y < _kill_y:
			_retire(body)


func _check(body: Block) -> bool:
	return EdgeRule.is_fallen(body.world_center_of_mass(), _platform.half_width,
			_platform.half_depth, _margin, _kill_y)


## Below fall_kill_y: stop simulating and hide (stands in for the docs' KillZone, keeps the body budget low).
func _retire(body: Block) -> void:
	body.set_fallen(true)
	body.visible = false
	body.set_deferred("freeze", true)
