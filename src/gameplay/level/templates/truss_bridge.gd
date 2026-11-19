extends TowerTemplate
## truss_bridge (docs/03 §4, difficulty 20–70; picture 03 left): a wooden truss between two stone
## columns carrying stone floors.
##   columns (stone cube stacks) -> bottom chord (plank_l) -> crystal centre post (pillar_2, the
##   KEYSTONE, "kafesin orta dikmesi") + two wooden wedge braces (a ball's width away from the post,
##   so it stays hittable) -> top chord (plank_l) balanced on
##   the post -> stone floors at both ends of the top chord, Golden Core in the middle.
## Break the post and the top chord with its floors has nothing left to stand on.
## Params: height (-> column height), block_count (-> floors), depth_layers, core (default true).

const COLUMN := "cube"
const CHORD := "plank_l"
const POST := "pillar_2"
const BRACE := "wedge"
const LOAD := "cube"
const MAX_COLUMN := 3
## Stone floors on the top chord: one level only — two levels rocked the chord balanced on the
## single post past physics.max_settle_drift (measured at d=70).
const MAX_FLOORS := 1
const MAX_DEPTH_LAYERS := 2
## Fixed parts per frame: 2 chords + post + 2 braces.
const FIXED_PARTS := 5


func id() -> String:
	return "truss_bridge"


func _build(p: Dictionary, _rng: RandomNumberGenerator) -> void:
	var gap := float(GameConfig.rule("generator.block_gap"))
	var cube := size_of(COLUMN)
	var chord := size_of(CHORD)
	var post := size_of(POST)
	var brace := size_of(BRACE)
	var load := size_of(LOAD)
	var depth := clampi(p_int(p, "depth_layers", 1), 1, MAX_DEPTH_LAYERS)
	var truss_h := chord.y + post.y + chord.y
	var column := clampi(roundi((p_float(p, "height", 6.0) - truss_h - load.y) / cube.y), 1, MAX_COLUMN)
	var budget := p_int(p, "block_count", 12)
	var per_frame := budget / depth
	var floors := clampi((per_frame - FIXED_PARTS - 2 * column) / 2, 1, MAX_FLOORS)
	# Columns sit under the chord ends, flush with them.
	var col_x := chord.x / 2.0 - cube.x / 2.0
	# Braces leave a ball-wide channel in front of the post (they are deeper than the post), so the
	# keystone can still be hit head-on (docs/03 §4 rule 3).
	var ball_r := float(GameConfig.ball(GameConfig.starting_ball_id())["radius"])
	var brace_x := ball_r + gap + brace.x / 2.0
	var load_x := chord.x / 2.0 - load.x / 2.0

	for f in depth:
		var z := (f - (depth - 1) / 2.0) * (maxf(chord.z, cube.z) + gap)
		var front := f == depth - 1
		var y := 0.0
		for h in column:
			for side: float in [-1.0, 1.0]:
				add_block(COLUMN, ROLE_STRUCTURE, Vector3(side * col_x, h * cube.y, z))
		y = column * cube.y
		add_block(CHORD, ROLE_LIGHT, Vector3(0, y, z))
		y += chord.y
		add_block(POST, ROLE_CRYSTAL, Vector3(0, y, z), Vector3.ZERO, front)
		add_block(BRACE, ROLE_LIGHT, Vector3(-brace_x, y, z))
		add_block(BRACE, ROLE_LIGHT, Vector3(brace_x, y, z), Vector3(0, 180, 0))
		y += post.y
		add_block(CHORD, ROLE_LIGHT, Vector3(0, y, z))
		y += chord.y
		for fl in floors:
			for side: float in [-1.0, 1.0]:
				add_block(LOAD, ROLE_STRUCTURE, Vector3(side * load_x, y + fl * load.y, z))
		if front and p_bool(p, "core", true):
			add_core(Vector3(0, y, z))
