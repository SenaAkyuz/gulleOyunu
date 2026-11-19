extends TowerTemplate
## staircase (docs/03 §4, difficulty 10–50): a stepped tower leaning to one side. Row r holds
## base - r cubes; each row starts one cube further in on the step side (the steps) and is pushed
## `lean` further out on the other side, so the tall wall leans over. Lean direction comes from the
## seed. The lean is limited so that, for every row, the combined centre of mass of everything
## above stays at least 3 x physics.support_margin inside the row below (SupportCheck confirms).
## Keystone: the bottom crystal cube under the leaning wall (front layer): break it and the
## wall tips over.
## Params: block_count (-> base), depth_layers, symmetry (lower = more lean), core (default true).

const SHAPE := "cube"
const MIN_BASE := 2
const MAX_DEPTH_LAYERS := 3
## Largest lean (fraction of a cube per row) at symmetry 0; symmetry 1 = no lean.
const MAX_LEAN := 0.4
const LEAN_STEP := 0.05
## Safety factor on physics.support_margin for the template's own lean limit.
const MARGIN_FACTOR := 3.0


func id() -> String:
	return "staircase"


func _build(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var gap := float(GameConfig.rule("generator.block_gap"))
	var size := size_of(SHAPE)
	var step_x := size.x + gap
	var step_z := size.z + gap
	var depth := clampi(p_int(p, "depth_layers", 1), 1, MAX_DEPTH_LAYERS)
	var budget := p_int(p, "block_count", 6)
	var guide: Dictionary = GameConfig.rule("dev.play_area_guide")
	var max_base := floori((float(guide["max"][0]) - float(guide["min"][0])) / step_x) - 2
	var base := MIN_BASE
	while base < max_base and depth * (base + 1) * (base + 2) / 2 <= budget:
		base += 1
	var dir := -1.0 if rng.randf() < 0.5 else 1.0
	var lean := snappedf(MAX_LEAN * (1.0 - p_float(p, "symmetry", 1.0)), LEAN_STEP)
	var margin := MARGIN_FACTOR * float(GameConfig.rule("physics.support_margin"))
	while lean > 0.0 and not _balanced(base, lean, step_x, size.x, margin):
		lean -= LEAN_STEP
	lean = maxf(lean, 0.0)

	# Centre the footprint of the bottom row on the origin.
	var x0 := -(base - 1) / 2.0 * step_x
	var top := Vector3.ZERO
	for row in base:
		var count := base - row
		for i in count:
			# Local x along the lean direction: steps start at row * step_x, plus the lean.
			var u := x0 + (row + i) * step_x + row * lean
			var x := u * dir
			for j in depth:
				var z := (j - (depth - 1) / 2.0) * step_z
				var front := j == depth - 1
				var key := row == 0 and i == count - 1 and front
				var role := ROLE_STRUCTURE if row < base / 2 else ROLE_LIGHT
				if key or (row == base - 1):
					role = ROLE_CRYSTAL
				add_block(SHAPE, role, Vector3(x, row * size.y, z), Vector3.ZERO, key)
				if front:
					top = Vector3(x, (row + 1) * size.y, z)
	if p_bool(p, "core", true):
		add_core(top)


## Every row: COM of all rows above (equal cubes) within [left, right] of the row's top face, by margin.
static func _balanced(base: int, lean: float, step: float, width: float, margin: float) -> bool:
	for row in range(base - 1):
		var sum := 0.0
		var n := 0
		for r in range(row + 1, base):
			for i in base - r:
				sum += (r + i) * step + r * lean
				n += 1
		var com := sum / n
		var left := row * step + row * lean - width / 2.0
		var right := (base - 1) * step + row * lean + width / 2.0
		if com < left + margin or com > right - margin:
			return false
	return true
