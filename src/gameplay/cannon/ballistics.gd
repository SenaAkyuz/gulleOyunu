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
