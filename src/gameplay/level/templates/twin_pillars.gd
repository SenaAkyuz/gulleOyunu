extends TowerTemplate
## twin_pillars (docs/03 §4, difficulty 1–30): two pillars carrying a plank, repeated `floors` times
## upwards, with a load (cubes) and the Golden Core on the top plank. depth_layers frames stand one
## behind the other (z). Keystone: one bottom pillar of the front frame, in crystal: break it and
## the plank tips, taking the floors above with it.
## Params: height (-> floors), block_count (-> wide plank + load), depth_layers, core (default true).
## The load is at most MAX_LOAD_STACK cubes high per stack; budget left over is not used (the
## generator adds structures for big budgets).

const PILLAR := "pillar_2"
const PLANK_NARROW := "plank_s"
const PLANK_WIDE := "plank_l"
const LOAD := "cube"
const MAX_DEPTH_LAYERS := 3
## Blocks per frame and floor: two pillars + one plank.
const BLOCKS_PER_FLOOR := 3
const MAX_LOAD_STACK := 2


func id() -> String:
	return "twin_pillars"


func _build(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var gap := float(GameConfig.rule("generator.block_gap"))
	var depth := clampi(p_int(p, "depth_layers", 1), 1, MAX_DEPTH_LAYERS)
	var budget := p_int(p, "block_count", 6)
	var pillar := size_of(PILLAR)
	var floor_h := pillar.y + size_of(PLANK_NARROW).y
	var floors := maxi(1, roundi((p_float(p, "height", 3.0) - size_of(LOAD).y) / floor_h))
	# Keep at least one load cube per frame inside the budget.
	while floors > 1 and depth * (floors * BLOCKS_PER_FLOOR + 1) > budget:
		floors -= 1
	var load := maxi(1, (budget - depth * floors * BLOCKS_PER_FLOOR) / depth)
	var plank := PLANK_WIDE if load >= 3 else PLANK_NARROW
	var stacks := 2 if plank == PLANK_WIDE else 1
	load = mini(load, stacks * MAX_LOAD_STACK)
	var plank_size := size_of(plank)
	# Pillars stand half a pillar in from the plank ends, so the plank overhangs a little.
	var pillar_x := plank_size.x / 2.0 - pillar.x
	var key_side := -1.0 if rng.randf() < 0.5 else 1.0

	for f in depth:
		var z := (f - (depth - 1) / 2.0) * (plank_size.z + gap)
		var front := f == depth - 1
		var y := 0.0
		for fl in floors:
			for side: float in [-1.0, 1.0]:
				var key: bool = front and fl == 0 and side == key_side
				add_block(PILLAR, ROLE_CRYSTAL if key else ROLE_STRUCTURE, Vector3(side * pillar_x, y, z), Vector3.ZERO, key)
			y += pillar.y
			add_block(plank, ROLE_LIGHT, Vector3(0, y, z))
			y += plank_size.y
		_add_load(load, plank_size, pillar_x, y, z, gap, front and p_bool(p, "core", true),
				p_int(p, "core_protection", 0))


## Load cubes on the top plank: stacks over the pillars, alternating sides; core in the middle
## when the plank is wide enough, else on top of the first stack.
func _add_load(count: int, plank_size: Vector3, pillar_x: float, y: float, z: float, gap: float, core: bool,
		protection: int) -> void:
	var cube := size_of(LOAD)
	var core_d := 2.0 * float(GameConfig.shape(str(GameConfig.rule("objective_defaults.core_shape")))["colliders"][0]["radius"])
	var middle_free := pillar_x - cube.x / 2.0 - gap >= core_d / 2.0
	var xs: Array[float] = [0.0]
	if middle_free:
		xs = [-pillar_x, pillar_x]
	var heights := {}
	for i in count:
		var x: float = xs[i % xs.size()]
		var level_y: float = heights.get(x, y)
		add_block(LOAD, ROLE_CRYSTAL if i == count - 1 else ROLE_LIGHT, Vector3(x, level_y, z))
		heights[x] = level_y + cube.y
	if core:
		if middle_free:
			add_protected_core(Vector3(0, y, z), protection)
		else:
			add_protected_core(Vector3(xs[0], heights.get(xs[0], y), z), protection)
