class_name BlockDamage
extends RefCounted
## Damage model (docs/02 §6.3), pure functions:
##   damage = max(0, impulse - material.impact_threshold) x ball.damage_mult[material] x world/effect multipliers
## Block-on-block and block-on-platform hits use multiplier 1.0 (chain collapses hurt too).
## Faz 1 has no world/effect multipliers yet.

const DEFAULT_MULT := 1.0


static func damage(impulse: float, impact_threshold: float, multiplier: float) -> float:
	return maxf(0.0, impulse - impact_threshold) * multiplier


## balls.json -> damage_mult[material]; materials not listed take DEFAULT_MULT.
static func ball_multiplier(ball_id: String, material_id: String) -> float:
	var table: Dictionary = GameConfig.ball(ball_id).get("damage_mult", {})
	return float(table.get(material_id, DEFAULT_MULT))
