extends TowerTemplate
## domino_row (docs/03 §4, difficulty 5–50): rows of thin standing pillars running away from the
## camera (−z). The ball hits the front domino, it tips backwards into the next one -> chain.
## Keystone: the front domino of the middle row (wood: it must topple, not shatter).
## The back domino of every row carries a crystal; the Golden Core waits behind the middle row's
## last domino, near the back edge, so a complete chain pushes it off (jackpot).
## Params: block_count (-> rows x dominoes), core (default true). Dominoes keep their light
## material (keep_role) so they topple; the chain itself protects the core (no cradle).
## Dominoes are always pillar_3: in physics pillar_2 (too squat) never started a chain, pillar_3
## toppled 5/5 at spacing 0.4–0.5 x height (measured in Faz 3 Step 5).

const DOMINO := "pillar_3"
const CROWN := "cube"
## Centre-to-centre spacing as a fraction of the domino height (middle of the measured 0.4–0.5).
const SPACING_RATIO := 0.45
## Rows stand this far apart in x (fraction of the crown width, so crowns never touch).
const ROW_SPACING_RATIO := 1.5
const MIN_PER_ROW := 3
const MAX_ROWS := 4


func id() -> String:
	return "domino_row"


func _build(p: Dictionary, _rng: RandomNumberGenerator) -> void:
	var gap := float(GameConfig.rule("generator.block_gap"))
	var shape := DOMINO
	var dom := size_of(shape)
	var crown := size_of(CROWN)
	var spacing := dom.y * SPACING_RATIO
	var core_d := 2.0 * _core_radius()
	# Room in z: the playable depth minus the core behind the last domino.
	var guide: Dictionary = GameConfig.rule("dev.play_area_guide")
	var depth_room := float(guide["max"][2]) - float(guide["min"][2]) - core_d - dom.z - gap
	var max_per_row := maxi(MIN_PER_ROW, floori(depth_room / spacing) + 1)
	var budget := p_int(p, "block_count", 6)
	var rows := clampi(budget / (max_per_row + 1), 1, MAX_ROWS)
	var per_row := clampi(budget / rows - 1, MIN_PER_ROW, max_per_row)
	var length := (per_row - 1) * spacing
	var z_front := (length + core_d + gap) / 2.0  # centre the row + core on z = 0
	var row_dx := crown.x * ROW_SPACING_RATIO
	var mid := rows / 2

	for r in rows:
		var x := (r - (rows - 1) / 2.0) * row_dx
		for i in per_row:
			var z := z_front - i * spacing
			var key := r == mid and i == 0
			keep_role(add_block(shape, ROLE_LIGHT, Vector3(x, 0, z), Vector3.ZERO, key))
			if i == per_row - 1:
				add_block(CROWN, ROLE_CRYSTAL, Vector3(x, dom.y, z))
		if r == mid and p_bool(p, "core", true):
			var z_core := z_front - length - dom.z / 2.0 - gap - core_d / 2.0
			add_core(Vector3(x, 0, z_core))


func _core_radius() -> float:
	return float(GameConfig.shape(str(GameConfig.rule("objective_defaults.core_shape")))["colliders"][0]["radius"])
