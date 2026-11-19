extends TowerTemplate
## arch_shrine (docs/03 §4, difficulty 5–60): an arch (one compound body: 2 legs + lintel) standing
## on two cube feet, `floors` arches stacked lintel on lintel, optional side towers of cubes, and the
## Golden Core in a ring_hanger cradle — inside the bottom arch (protected) or on the top lintel.
## Keystone: one crystal foot of the front arch ("kemer ayağı"): break it and the arch drops on that
## side, taking the floors above with it.
## Params: floors (else from height), depth_layers, side_towers (default: true when the budget
## allows), core: true | false | "hanging_center" / "inside" | "top" (true: core_protection 0 -> top,
## >= 1 -> inside), block_count, symmetry.
## "hanging_center" sits in a cradle until rope/chain joints arrive (Faz 5).

const ARCH := "arch"
const FOOT := "cube"
const TOWER := "cube"
const MAX_FLOORS := 3
const MAX_DEPTH_LAYERS := 2
const CORE_INSIDE: PackedStringArray = ["hanging_center", "inside"]
const CORE_TOP := "top"


func id() -> String:
	return "arch_shrine"


func _build(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var gap := float(GameConfig.rule("generator.block_gap"))
	var arch := size_of(ARCH)
	var foot := size_of(FOOT)
	var leg_inner := _leg_inner_x()
	# Feet sit under the legs but start at the leg's inner edge, so the space under the arch stays
	# as wide as between the legs (room for the cradle).
	var foot_x := leg_inner + foot.x / 2.0
	var depth := clampi(p_int(p, "depth_layers", 1), 1, MAX_DEPTH_LAYERS)
	var floors := clampi(p_int(p, "floors", roundi((p_float(p, "height", 3.0) - foot.y) / arch.y)), 1, MAX_FLOORS)
	var core_mode := _core_mode(p)
	var key_side := -1.0 if rng.randf() < 0.5 else 1.0

	var used := 0
	var top_y := 0.0
	for f in depth:
		var z := (f - (depth - 1) / 2.0) * (arch.z + gap)
		var front := f == depth - 1
		for side: float in [-1.0, 1.0]:
			var key: bool = front and side == key_side
			add_block(FOOT, ROLE_CRYSTAL if key else ROLE_STRUCTURE, Vector3(side * foot_x, 0, z), Vector3.ZERO, key)
		var y := foot.y
		for fl in floors:
			add_block(ARCH, ROLE_STRUCTURE if fl == 0 else ROLE_LIGHT, Vector3(0, y, z))
			y += arch.y
		used += 2 + floors
		top_y = y
		var protection := p_int(p, "core_protection", 0)
		if front and core_mode == CORE_TOP:
			add_protected_core(Vector3(0, top_y, z), protection)
			used += 1
		elif front and CORE_INSIDE.has(core_mode):
			# Under the arch the core always sits in a cradle (no lid: the arch is the roof).
			add_protected_core(Vector3(0, 0, z), 1)
			used += 1

	# Side towers from the rest of the budget: one cube column on each side, crystal on top.
	var budget := p_int(p, "block_count", used)
	var per_side := mini((budget - used) / (2 * depth), roundi(top_y / foot.y))
	if p_bool(p, "side_towers", per_side >= 2) and per_side >= 1:
		var tower_x := foot_x + foot.x / 2.0 + gap + size_of(TOWER).x / 2.0
		for f in depth:
			var z := (f - (depth - 1) / 2.0) * (arch.z + gap)
			for side: float in [-1.0, 1.0]:
				for h in per_side:
					var role := ROLE_CRYSTAL if h == per_side - 1 else (ROLE_STRUCTURE if h == 0 else ROLE_LIGHT)
					add_block(TOWER, role, Vector3(side * tower_x, h * size_of(TOWER).y, z))


## Inner edge of the arch legs (from the arch's leg colliders in shapes.json).
func _leg_inner_x() -> float:
	var inner := INF
	for c: Dictionary in GameConfig.shape(ARCH)["colliders"]:
		var x := absf(float(c["pos"][0]))
		if x > 0.0:
			inner = minf(inner, x - float(c["size"][0]) / 2.0)
	return inner


func _core_mode(p: Dictionary) -> String:
	var c: Variant = p.get("core", true)
	if c is String:
		return str(c)
	if not bool(c):
		return ""
	return CORE_TOP if p_int(p, "core_protection", 0) == 0 else CORE_INSIDE[1]
