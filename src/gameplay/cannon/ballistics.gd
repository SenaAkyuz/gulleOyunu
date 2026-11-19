class_name Ballistics
extends RefCounted
## Launch-velocity solver for a fixed launch speed (tap_target, plan §4).
## tan(theta) = (v^2 -/+ sqrt(v^4 - g(g d^2 + 2 h v^2))) / (g d)
##   d = horizontal distance, h = height difference, "low" arc takes the minus root.
## Out of range (negative discriminant): fire at 45 degrees towards the target (max range).

const ARC_LOW := "low"
const ARC_HIGH := "high"
## Below this horizontal distance the target is (almost) straight above/below: aim directly.
const MIN_HORIZONTAL_DISTANCE := 0.001


## Returns the launch velocity. `reachable` tells whether the exact solution existed.
static func solve(from: Vector3, to: Vector3, speed: float, gravity: float, arc: String) -> Dictionary:
	var delta := to - from
	var flat := Vector3(delta.x, 0.0, delta.z)
	var d := flat.length()
	if d < MIN_HORIZONTAL_DISTANCE or gravity <= 0.0:
		return {"velocity": delta.normalized() * speed, "reachable": true}
	var h := delta.y
	var v2 := speed * speed
	var disc := v2 * v2 - gravity * (gravity * d * d + 2.0 * h * v2)
	var theta: float
	var reachable := disc >= 0.0
	if reachable:
		var root := sqrt(disc)
		var numerator := v2 - root if arc == ARC_LOW else v2 + root
		theta = atan(numerator / (gravity * d))
	else:
		theta = PI / 4.0
	var horizontal := flat / d
	return {
		"velocity": horizontal * speed * cos(theta) + Vector3.UP * speed * sin(theta),
		"reachable": reachable,
	}


## Time for a ball launched from `from` with `velocity` to reach `to` (horizontal distance based;
## straight up/down shots use the full distance).
static func time_to_reach(from: Vector3, to: Vector3, velocity: Vector3) -> float:
	var delta := to - from
	var flat_d := Vector2(delta.x, delta.z).length()
	var flat_v := Vector2(velocity.x, velocity.z).length()
	if flat_d < MIN_HORIZONTAL_DISTANCE or flat_v <= 0.0:
		return delta.length() / maxf(velocity.length(), MIN_HORIZONTAL_DISTANCE)
	return flat_d / flat_v


## Position after t seconds (used by the trajectory preview).
static func point_at(from: Vector3, velocity: Vector3, gravity: float, t: float) -> Vector3:
	return from + velocity * t + Vector3.DOWN * gravity * t * t / 2.0


## Launch velocity for a yaw/pitch pair (drag_release). yaw 0 = towards -Z (the tower),
## positive yaw turns right (+X); positive pitch aims up.
static func velocity_from_angles(yaw_deg: float, pitch_deg: float, speed: float) -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	var flat := Vector3(sin(yaw), 0.0, -cos(yaw))
	return flat * speed * cos(pitch) + Vector3.UP * speed * sin(pitch)


## Time until a ball from `from` with `velocity` comes down to height `y` (later root);
## returns -1 if it never gets there.
static func time_to_height(from: Vector3, velocity: Vector3, gravity: float, y: float) -> float:
	# from.y + vy t - g t^2 / 2 = y
	var a := -gravity / 2.0
	var b := velocity.y
	var c := from.y - y
	if is_zero_approx(a):
		return -c / b if b != 0.0 else -1.0
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var root := sqrt(disc)
	return maxf((-b - root) / (2.0 * a), (-b + root) / (2.0 * a))
