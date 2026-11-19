extends GutTest
## Faz 3 Step 5: domino_row + truss_bridge (docs/03 §4), same checks as Steps 3–4 over
## d = 1/15/25 and each template's own range, 3 seeds; plus a real domino chain in physics
## and the truss keystone being the centre post.

const Kit = preload("res://tests/helpers/template_kit.gd")
const SEEDS := [1, 2, 3]
const RANGES := {
	"domino_row": [1.0, 15.0, 25.0, 5.0, 30.0, 50.0],
	"truss_bridge": [1.0, 15.0, 25.0, 20.0, 45.0, 70.0],
}
## Seconds to let the chain run; impulse (N·s per kg of the domino) for the first push — still far
## below a real hit (heavy ball: 2 kg x 22 m/s = 44 N·s). Measured: spacing 0.45 x height topples
## 4/4 within 2 s at this push; 0.40 and below break the chain.
const CHAIN_SECONDS := 4.0
const PUSH_PER_KG := 5.0
const RELEASE_FRAMES := 5


func test_static_checks_over_range() -> void:
	for t: String in RANGES:
		for d: float in RANGES[t]:
			for s: int in SEEDS:
				var bad := Kit.problems(Kit.level(t, d, s))
				assert_eq(bad.size(), 0, "%s d=%d seed=%d: %s" % [t, d, s, "; ".join(bad)])


func test_physics_does_not_drift() -> void:
	for t: String in RANGES:
		for d: float in RANGES[t]:
			var r: Dictionary = await SupportCheck.physics_drift(Kit.level(t, d, 1), self)
			assert_true(r["ok"], "%s d=%d: en çok kayan %s %.4f m" % [t, d, r["worst"], r["max_drift"]])


func test_domino_chain_reaches_the_end() -> void:
	for d: float in [5.0, 30.0]:
		var lv := Kit.level("domino_row", d, 1)
		var holder := Node3D.new()
		var plat := Platform.new()
		var tower := TowerBuilder.new()
		holder.add_child(plat)
		holder.add_child(tower)
		add_child(holder)
		plat.build(float(lv["platform"]["width"]), float(lv["platform"]["depth"]))
		tower.build(lv)
		await wait_physics_frames(RELEASE_FRAMES)  # TowerBuilder unfreezes after the first tick
		var key: Block = null
		for b in tower.blocks:
			if lv["keystones"].has(b.block_id):
				key = b
		key.sleeping = false
		# Push the top of the first domino away from the camera, like a ball hit.
		var top := Vector3(0, LayoutCheck.block_aabb({"shape": key.shape_id, "mat": key.material_id,
				"x": 0, "y": 0, "z": 0}).size.y * 0.9, 0)
		key.apply_impulse(Vector3.BACK * -PUSH_PER_KG * key.mass, top)
		await wait_seconds(CHAIN_SECONDS)
		var core_moved := tower.cores[0].drift()
		var crowns_moved := 0
		for b in tower.blocks:
			if b.shape_id == "cube" and b.drift() > 0.5:
				crowns_moved += 1
		assert_gt(crowns_moved, 0, "d=%d: zincir sondaki kristale ulaşmalı" % d)
		assert_gt(core_moved, 0.1, "d=%d: zincir küreyi itmeli (%.2f m)" % [d, core_moved])
		holder.queue_free()
		await wait_process_frames(1)


func test_truss_keystone_is_centre_post() -> void:
	var lv := Kit.level("truss_bridge", 45.0, 1)
	assert_eq((lv["keystones"] as Array).size(), 1)
	for b: Dictionary in lv["blocks"]:
		if b["id"] == lv["keystones"][0]:
			assert_eq(b["shape"], "pillar_2")
			assert_almost_eq(float(b["x"]), 0.0, 0.001)
			assert_true(str(b["mat"]).begins_with("crystal"))


func test_domino_footprint_wider_than_deep() -> void:
	# Sena: rows side by side (docs/03 §4 "yan yana"); a single row seen head-on read as one pillar.
	for d: float in RANGES["domino_row"]:
		for s: int in SEEDS:
			var lv := Kit.level("domino_row", d, s)
			var box := LevelGenerator._bounds(lv)
			assert_gte(box.size.x, box.size.z, "domino d=%d seed=%d: genişlik %.2f < derinlik %.2f" % [d, s, box.size.x, box.size.z])
			var rows := {}
			for b: Dictionary in lv["blocks"]:
				rows[snappedf(float(b["x"]), 0.01)] = true
			assert_gte(rows.size(), 3, "domino d=%d: en az 3 sıra" % d)
