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
	_build(p, rng)
	return {"blocks": blocks.duplicate(true), "keystones": keystones.duplicate(), "cores": cores.duplicate(true)}


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
