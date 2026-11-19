class_name LayoutCheck
extends RefCounted
## Placement rules of an (expanded) level that need no physics (docs/03 §2, §4 rules 5 and 7):
##  - every block inside the playable tower area (rules.dev.play_area_guide);
##  - every block's footprint at least rules.physics.spawn_edge_inset inside the platform;
##  - at least one keystone, and every keystone id exists;
##  - at least one shatter (crystal) block: "every tower has something shiny to break".
## Also builds the platform size a template level needs (footprint + generator.platform_margin).

const SHATTER_FLAG := "shatter"


## {ok, issues: [String]}
static func check(level: Dictionary) -> Dictionary:
	var issues: PackedStringArray = []
	var guide: Dictionary = GameConfig.rule("dev.play_area_guide")
	var area := AABB(ShapeBuilder.to_vec3(guide["min"]), ShapeBuilder.to_vec3(guide["max"]) - ShapeBuilder.to_vec3(guide["min"]))
	var inset := float(GameConfig.rule("physics.spawn_edge_inset"))
	var plat: Dictionary = level.get("platform", {})
	var hw := float(plat.get("width", 0)) / 2.0 - inset
	var hd := float(plat.get("depth", 0)) / 2.0 - inset
	var tol := float(GameConfig.rule("physics.support_contact_epsilon"))
	var ids := {}
	var crystals := 0
	for b: Dictionary in level.get("blocks", []):
		var id := str(b.get("id", "?"))
		ids[id] = true
		var box := block_aabb(b)
		if not area.grow(tol).encloses(box):
			issues.append("%s oyun alanının dışında" % id)
		if box.position.y < -tol:
			issues.append("%s platformun içine gömülü" % id)
		if box.position.x < -hw - tol or box.end.x > hw + tol or box.position.z < -hd - tol or box.end.z > hd + tol:
			issues.append("%s platform kenarına %.2f'den yakın" % [id, inset])
		if (GameConfig.material(str(b.get("mat", ""))).get("flags", []) as Array).has(SHATTER_FLAG):
			crystals += 1
	var keystones: Array = level.get("keystones", [])
	if keystones.is_empty():
		issues.append("keystone yok")
	for k in keystones:
		if not ids.has(str(k)):
			issues.append("keystone %s bölümde yok" % k)
	if crystals == 0:
		issues.append("kırılacak kristal yok")
	return {"ok": issues.is_empty(), "issues": issues}


## World AABB of a block dict (all collider pieces).
static func block_aabb(b: Dictionary) -> AABB:
	var body := SupportCheck._body(str(b.get("id", "")), str(b["shape"]), str(b["mat"]), b)
	var box: AABB = (body["pieces"][0] as Dictionary)["aabb"]
	for p: Dictionary in body["pieces"]:
		box = box.merge(p["aabb"])
	return box


## Platform {width, depth} centred on the origin that holds every block with
## spawn_edge_inset + generator.platform_margin around the footprint.
static func platform_for(blocks: Array) -> Dictionary:
	var pad := float(GameConfig.rule("physics.spawn_edge_inset")) + float(GameConfig.rule("generator.platform_margin"))
	var half_x := 0.0
	var half_z := 0.0
	for b: Dictionary in blocks:
		var box := block_aabb(b)
		half_x = maxf(half_x, maxf(absf(box.position.x), absf(box.end.x)))
		half_z = maxf(half_z, maxf(absf(box.position.z), absf(box.end.z)))
	return {"width": snappedf(2.0 * (half_x + pad), 0.01), "depth": snappedf(2.0 * (half_z + pad), 0.01)}
