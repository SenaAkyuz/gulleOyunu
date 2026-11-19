extends TowerTemplate
## Test-only template: one structure block at (1, 0, 0) (keystone), one crystal on top whose
## x comes from the rng, a core, and a block_count echo so tests can see the params.


func id() -> String:
	return "probe"


func _build(p: Dictionary, rng: RandomNumberGenerator) -> void:
	add_block("cube", ROLE_STRUCTURE, Vector3(1, 0, 0), Vector3.ZERO, true)
	add_block("cube", ROLE_CRYSTAL, Vector3(rng.randf_range(-1.0, 1.0), 1, 0))
	add_block("cube", "wood", Vector3(0, 0, float(p_int(p, "block_count", 0))))
	add_core(Vector3(1, 2, 0))
