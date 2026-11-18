class_name EdgeRule
extends RefCounted
## "Did it fall?" rule (docs/02 §2, rules.physics.edge_rule). Pure functions, no scene access.
## com_outside_platform: a body has fallen if the horizontal (x, z) projection of its centre of
## mass is outside the platform top (with edge_margin tolerance) OR it is below fall_kill_y.
## No in-between state.

const COM_OUTSIDE_PLATFORM := "com_outside_platform"


static func is_fallen(com: Vector3, half_width: float, half_depth: float,
		margin: float, kill_y: float) -> bool:
	if com.y < kill_y:
		return true
	return absf(com.x) > half_width + margin or absf(com.z) > half_depth + margin
