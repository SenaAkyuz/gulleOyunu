extends TowerTemplate
## stack_pyramid (docs/03 §4, difficulty 1–25): cube pyramid, each row sitting half a cube in from
## the row below, depth_layers rows deep (z), Golden Core on the apex.
## Keystone: the bottom-middle cube of the front (camera-side) layer, made of crystal so one hit
## breaks it and the cubes above lose half their support.
## Params: block_count (size: the largest pyramid that fits the budget), depth_layers (1–3),
## symmetry (< 1: the upper rows may lose a cube on one side), core (default true).

const SHAPE := "cube"
const MIN_BASE := 2
const MAX_DEPTH_LAYERS := 3


func id() -> String:
	return "stack_pyramid"


func _build(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var gap := float(GameConfig.rule("generator.block_gap"))
	var size := size_of(SHAPE)
	var depth := clampi(p_int(p, "depth_layers", 1), 1, MAX_DEPTH_LAYERS)
	var budget := p_int(p, "block_count", 6)
	var step_x := size.x + gap
	var step_z := size.z + gap

	# Largest base that fits the budget and the playable width (rules.dev.play_area_guide).
	var guide: Dictionary = GameConfig.rule("dev.play_area_guide")
	var max_base := floori((float(guide["max"][0]) - float(guide["min"][0])) / step_x) - 1
	var base := MIN_BASE
	while base < max_base and depth * (base + 1) * (base + 2) / 2 <= budget:
		base += 1

	# Asymmetry: the upper rows may lose their end cube on one side (one side for the whole tower).
	var trim_side := 0
	if rng.randf() > p_float(p, "symmetry", 1.0):
		trim_side = -1 if rng.randf() < 0.5 else 1

	var top_y := 0.0
	for row in base:
		var count := base - row
		var y := row * size.y
		for i in count:
			var x := (i - (count - 1) / 2.0) * step_x
			if trim_side != 0 and row > 0 and row < base - 1 and i == (0 if trim_side < 0 else count - 1):
				continue
			for j in depth:
				var z := (j - (depth - 1) / 2.0) * step_z
				var front := j == depth - 1
				var key := row == 0 and front and i == count / 2
				var role := ROLE_STRUCTURE if row < base / 2 else ROLE_LIGHT
				if key or row == base - 1:
					role = ROLE_CRYSTAL
				add_block(SHAPE, role, Vector3(x, y, z), Vector3.ZERO, key)
		top_y = y + size.y
	if p_bool(p, "core", true):
		add_core(Vector3(0, top_y, 0))
