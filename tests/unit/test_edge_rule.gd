extends GutTest
## Edge rule com_outside_platform (docs/02 §2): fallen when the centre of mass is outside the
## platform rectangle (+ margin) or below fall_kill_y.

const HALF_W := 1.5
const HALF_D := 1.0
const MARGIN := 0.05
const KILL_Y := -3.0


func test_inside_is_not_fallen() -> void:
	assert_false(EdgeRule.is_fallen(Vector3(1.4, 0.5, 0.9), HALF_W, HALF_D, MARGIN, KILL_Y))


func test_inside_margin_is_not_fallen() -> void:
	assert_false(EdgeRule.is_fallen(Vector3(1.54, 0.5, 0.0), HALF_W, HALF_D, MARGIN, KILL_Y))


func test_outside_x_is_fallen() -> void:
	assert_true(EdgeRule.is_fallen(Vector3(1.6, 0.5, 0.0), HALF_W, HALF_D, MARGIN, KILL_Y))


func test_outside_z_is_fallen() -> void:
	assert_true(EdgeRule.is_fallen(Vector3(0.0, 0.5, -1.1), HALF_W, HALF_D, MARGIN, KILL_Y))


func test_below_kill_y_is_fallen() -> void:
	assert_true(EdgeRule.is_fallen(Vector3(0.0, -3.5, 0.0), HALF_W, HALF_D, MARGIN, KILL_Y))
