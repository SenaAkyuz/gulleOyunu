extends GutTest
## Ballistics (cannon/ballistics.gd): the launch solver must land the ball on the target.

const SPEED := 22.0
const GRAVITY := 9.8
const FROM := Vector3(0, 1, 6)
const LAND_TOLERANCE := 0.01


func _landing_error(target: Vector3, arc: String) -> float:
	var sol := Ballistics.solve(FROM, target, SPEED, GRAVITY, arc)
	var v: Vector3 = sol["velocity"]
	var t := Ballistics.time_to_reach(FROM, target, v)
	return Ballistics.point_at(FROM, v, GRAVITY, t).distance_to(target)


func test_low_arc_hits_target() -> void:
	assert_lt(_landing_error(Vector3(0.7, 1.0, 0.3), "low"), LAND_TOLERANCE)


func test_high_arc_hits_target() -> void:
	assert_lt(_landing_error(Vector3(-1.0, 3.0, 0.0), "high"), LAND_TOLERANCE)


func test_speed_is_fixed() -> void:
	var v: Vector3 = Ballistics.solve(FROM, Vector3(1, 2, 0), SPEED, GRAVITY, "low")["velocity"]
	assert_almost_eq(v.length(), SPEED, 0.001)


func test_out_of_range_is_flagged() -> void:
	var sol := Ballistics.solve(FROM, Vector3(0, 0, -200), SPEED, GRAVITY, "low")
	assert_false(sol["reachable"])


func test_velocity_from_angles_straight_ahead() -> void:
	var v := Ballistics.velocity_from_angles(0.0, 0.0, SPEED)
	assert_almost_eq(v.z, -SPEED, 0.001, "yaw 0 points at the tower (-Z)")
	assert_almost_eq(v.y, 0.0, 0.001)


func test_velocity_from_angles_right_and_up() -> void:
	var v := Ballistics.velocity_from_angles(30.0, 20.0, SPEED)
	assert_gt(v.x, 0.0, "positive yaw turns right (+X)")
	assert_gt(v.y, 0.0, "positive pitch aims up")


func test_time_to_height_lands() -> void:
	var v := Vector3(0, 5, -10)
	var t := Ballistics.time_to_height(FROM, v, GRAVITY, 0.0)
	assert_almost_eq(Ballistics.point_at(FROM, v, GRAVITY, t).y, 0.0, 0.001)
