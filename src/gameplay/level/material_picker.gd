class_name MaterialPicker
extends RefCounted
## Turns a template block "role" into a material id from the world palette (docs/03 §6.3).
## Faz 3 Step 1: simple deterministic choice so templates can be seen and tested:
##   crystal   -> a palette material with the "shatter" flag
##   structure -> the densest non-shatter palette material
##   light     -> the lightest non-shatter palette material
## Step 6 replaces it with the palette weights + heavy_ratio + role rules.

const SHATTER_FLAG := "shatter"


static func pick(role: String, world: Dictionary, _p: Dictionary, _rng: RandomNumberGenerator) -> String:
	var ids := PackedStringArray((world.get("palette", {}) as Dictionary).keys())
	ids.sort()
	if ids.is_empty():
		return ""
	var solid: Array[String] = []
	var shatter: Array[String] = []
	for m in ids:
		(shatter if _shatters(m) else solid).append(m)
	solid.sort_custom(func(a: String, b: String) -> bool: return _density(a) < _density(b))
	match role:
		TowerTemplate.ROLE_CRYSTAL:
			if not shatter.is_empty():
				return shatter[0]
		TowerTemplate.ROLE_STRUCTURE:
			if not solid.is_empty():
				return solid[-1]
		TowerTemplate.ROLE_LIGHT:
			if not solid.is_empty():
				return solid[0]
	return ids[0]


static func _shatters(mat: String) -> bool:
	return (GameConfig.material(mat).get("flags", []) as Array).has(SHATTER_FLAG)


static func _density(mat: String) -> float:
	return float(GameConfig.material(mat).get("density", 0.0))
