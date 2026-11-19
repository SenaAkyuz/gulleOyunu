extends GutTest
## Damage formula (docs/02 §6.3): max(0, impulse - impact_threshold) x multiplier.


func test_below_threshold_does_nothing() -> void:
	assert_eq(BlockDamage.damage(2.0, 2.5, 1.0), 0.0)


func test_above_threshold_minus_threshold() -> void:
	assert_almost_eq(BlockDamage.damage(14.0, 2.5, 1.0), 11.5, 0.0001)


func test_multiplier_scales() -> void:
	assert_almost_eq(BlockDamage.damage(16.0, 6.0, 0.6), 6.0, 0.0001)


func test_ball_multiplier_from_balls_json() -> void:
	var heavy: Dictionary = GameConfig.ball("heavy")
	var metal_mult := float(heavy["damage_mult"]["metal"])
	assert_almost_eq(BlockDamage.ball_multiplier("heavy", "metal"), metal_mult, 0.0001)


func test_ball_multiplier_default_for_unlisted_material() -> void:
	assert_almost_eq(BlockDamage.ball_multiplier("heavy", "crystal_amber"), BlockDamage.DEFAULT_MULT, 0.0001)
