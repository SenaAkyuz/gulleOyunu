class_name TowerTemplate
extends RefCounted
## Base class of a structure template (docs/03 §4): a parametric function that returns a block list
## in the structure's LOCAL frame (origin = structure x/z on the platform top, y = 0).
## LevelExpander moves/rotates the result into place and assigns ids and materials.
##
## Subclasses override _build(p, rng) and call add_block() / add_core(). p = difficulty curves
## (DifficultyCalc.params) merged with the level's structure "params"; rng is seeded from the
## structure "seed", so the same level file always gives the same tower.
##
## Block dictionary (same keys as a level "blocks" entry, docs/03 §2.1):
##   shape, x, y, z, rot [rx, ry, rz]; and either "mat" (explicit material id) or "role":
##   ROLE_STRUCTURE (load-bearing: heavy material), ROLE_LIGHT (upper floors), ROLE_CRYSTAL
##   (something shiny to break). MaterialPicker turns roles into materials (world palette).

const ROLE_STRUCTURE := "structure"
const ROLE_LIGHT := "light"
const ROLE_CRYSTAL := "crystal"
## Golden Core protection pieces (add_protected_core).
const CRADLE := "ring_hanger"
const LID := "plank_s"
## "raised" variant: the structure stands on a deck carried by two stilts per deck row (Faz 3,
## ground_contact_max_ratio). Decks from short to long; the shortest that spans the footprint is used.
const DECKS: PackedStringArray = ["plank_s", "plank_l", "beam"]
const STILT := "pillar_2"
## Blocks the raised variant adds per deck row (two stilts + the deck).
const RAISE_BLOCKS := 3

var blocks: Array[Dictionary] = []
## Local ids ("b01", ...) of the keystone blocks (docs/03 §4 rule 2: at least one).
var keystones: PackedStringArray = []
var cores: Array[Dictionary] = []


## Template id as used in level files and worlds.allowed_templates.
func id() -> String:
	return ""


## Runs the template. Returns {"blocks": [...], "keystones": [...], "cores": [...]} (local frame).
func generate(p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	blocks.clear()
	keystones.clear()
	cores.clear()
	var raised := p_bool(p, "raised", false)
	if raised:
		# Leave room in the block budget for the stilts and the deck.
		p = p.duplicate()
		p["block_count"] = maxi(1, p_int(p, "block_count", RAISE_BLOCKS) - RAISE_BLOCKS)
	_build(p, rng)
	if raised:
		_raise(rng)
	return {"blocks": blocks.duplicate(true), "keystones": keystones.duplicate(), "cores": cores.duplicate(true)}


## Parameter sets the generator may try, one per attempt in turn (merged into the structure's
## params). Templates with a wide base offer {"raised": true} so they can meet
## difficulty ground_contact_max_ratio in easy roles.
func variants() -> Array[Dictionary]:
	return [{}]


## Lifts everything onto decks (one deck row per ~deck depth) carried by two stilts each; one
## front stilt is a crystal keystone: break it and the deck tips with the whole structure.
func _raise(rng: RandomNumberGenerator) -> void:
	var box := _footprint()
	var gap := float(GameConfig.rule("generator.block_gap"))
	var deck := ""
	for d in DECKS:
		if size_of(d).x >= box.size.x:
			deck = d
			break
	if deck.is_empty():
		return  # too wide to raise: the ground check rejects the attempt
	var dsize := size_of(deck)
	var stilt := size_of(STILT)
	var lift := stilt.y + dsize.y
	for b in blocks:
		b["y"] = float(b["y"]) + lift
	for c in cores:
		c["y"] = float(c["y"]) + lift
	# Rounded, not ceiled: a footprint a little deeper than the deck may overhang its edges.
	var rows := maxi(1, roundi(box.size.z / (dsize.z + gap)))
	var cx := box.get_center().x
	var cz := box.get_center().z
	var stilt_x := dsize.x / 2.0 - stilt.x
	var key_side := -1.0 if rng.randf() < 0.5 else 1.0
	for r in rows:
		var z := cz + (r - (rows - 1) / 2.0) * (dsize.z + gap)
		var front := r == rows - 1
		for side: float in [-1.0, 1.0]:
			var key: bool = front and side == key_side
			add_block(STILT, ROLE_CRYSTAL if key else ROLE_STRUCTURE, Vector3(cx + side * stilt_x, 0, z), Vector3.ZERO, key)
		add_block(deck, ROLE_STRUCTURE, Vector3(cx, stilt.y, z))


## Bounding box (x, z) of the blocks and cores generated so far.
func _footprint() -> AABB:
	var box := AABB()
	var first := true
	for b in blocks:
		var rot := ShapeBuilder.to_vec3(b.get("rot", [0, 0, 0]))
		var xform := Transform3D(Basis.from_euler(rot * (PI / 180.0), EULER_ORDER_YXZ), Vector3(float(b["x"]), float(b["y"]), float(b["z"])))
		for c: Dictionary in GameConfig.shape(str(b["shape"])).get("colliders", []):
			var piece := SupportCheck._piece(c, xform)
			if piece.is_empty():
				continue
			box = piece["aabb"] if first else box.merge(piece["aabb"])
			first = false
	for c in cores:
		var p := Vector3(float(c["x"]), float(c["y"]), float(c["z"]))
		box = AABB(p, Vector3.ZERO) if first else box.expand(p)
		first = false
	return box


func _build(_p: Dictionary, _rng: RandomNumberGenerator) -> void:
	push_error("TowerTemplate: _build() yazılmamış (%s)" % id())


## Adds a block and returns its local id. role_or_mat: a ROLE_* constant or a material id.
func add_block(shape: String, role_or_mat: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO,
		keystone: bool = false) -> String:
	var local_id := "b%02d" % (blocks.size() + 1)
	var b := {"id": local_id, "shape": shape, "x": pos.x, "y": pos.y, "z": pos.z,
			"rot": [rot_deg.x, rot_deg.y, rot_deg.z]}
	if role_or_mat in [ROLE_STRUCTURE, ROLE_LIGHT, ROLE_CRYSTAL]:
		b["role"] = role_or_mat
	else:
		b["mat"] = role_or_mat
	blocks.append(b)
	if keystone:
		keystones.append(local_id)
	return local_id


## Golden Core resting at pos (y = bottom of the sphere).
func add_core(pos: Vector3) -> void:
	cores.append({"x": pos.x, "y": pos.y, "z": pos.z, "attach": "rest"})


## The block keeps its role's material class (MaterialPicker does not turn it heavy/light by
## heavy_ratio), e.g. dominoes that must stay light enough to topple.
func keep_role(local_id: String) -> void:
	for b in blocks:
		if b["id"] == local_id:
			b["keep_role"] = true


## Golden Core on a flat top at `base` (docs/03 §4 rule 6a, difficulty core_protection):
##   0  -> the core lies loose on top
##   1  -> in a ring_hanger cradle (it only leaves when the cradle goes)
##   >=2 -> cradle + a plank lid on the cradle posts
func add_protected_core(base: Vector3, protection: int) -> void:
	if protection <= 0:
		add_core(base)
		return
	add_block(CRADLE, ROLE_LIGHT, base)
	add_core(base + Vector3(0, _cradle_bar_top(), 0))
	if protection >= 2:
		add_block(LID, ROLE_LIGHT, base + Vector3(0, _cradle_post_top(), 0))


## Top of the cradle's posts (the lid rests there; shapes.json "size" is the bounding box, not the posts).
static func _cradle_post_top() -> float:
	var top := 0.0
	for c: Dictionary in GameConfig.shape(CRADLE)["colliders"]:
		top = maxf(top, float(c["pos"][1]) + float(c["size"][1]) / 2.0)
	return top


static func _cradle_bar_top() -> float:
	for c: Dictionary in GameConfig.shape(CRADLE)["colliders"]:
		var pos := ShapeBuilder.to_vec3(c["pos"])
		if is_zero_approx(pos.x):  # the bottom bar
			return pos.y + float(c["size"][1]) / 2.0
	return 0.0


## Shape size [x, y, z] from shapes.json (templates stack blocks with it, no hard-coded sizes).
static func size_of(shape: String) -> Vector3:
	return ShapeBuilder.to_vec3(GameConfig.shape(shape).get("size", [1, 1, 1]))


## Integer parameter with a default (structure params override the difficulty curves).
static func p_int(p: Dictionary, key: String, default: int) -> int:
	return int(p.get(key, default))


static func p_float(p: Dictionary, key: String, default: float) -> float:
	return float(p.get(key, default))


static func p_bool(p: Dictionary, key: String, default: bool) -> bool:
	return bool(p.get(key, default))
