extends TowerTemplate
## Test-only template that always fails SupportCheck: a crystal keystone floating in the air.


func id() -> String:
	return "floating"


func _build(_p: Dictionary, _rng: RandomNumberGenerator) -> void:
	add_block("cube", ROLE_CRYSTAL, Vector3(0, 1, 0), Vector3.ZERO, true)
