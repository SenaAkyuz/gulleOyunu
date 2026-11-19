extends GutTest
## KeystoneCheck (docs/03 §4 rule 3, S-007) and LayoutCheck on known cases.


func _lv(blocks: Array, keystones: Array, w: float = 6.0, d: float = 4.0) -> Dictionary:
	return {"id": "t", "platform": {"width": w, "depth": d}, "blocks": blocks, "keystones": keystones, "cores": []}


func _b(id: String, shape: String, x: float, y: float, z: float, mat: String = "stone") -> Dictionary:
	return {"id": id, "shape": shape, "mat": mat, "x": x, "y": y, "z": z, "rot": [0, 0, 0]}


func test_level_01_keystone_ok() -> void:
	var r := KeystoneCheck.check(GameConfig.level("w01_l01"))
	assert_true(r["ok"], "; ".join(r["issues"]))
	assert_gt(float(r["keystones"]["b02"]["visible_ratio"]), 0.5)


func test_open_cube_visible_and_reachable() -> void:
	var r := KeystoneCheck.check(_lv([_b("k", "cube", 0, 0, 0, "crystal_amber")], ["k"]))
	assert_true(r["ok"], "; ".join(r["issues"]))
	assert_eq(r["keystones"]["k"]["via"], KeystoneCheck.VIA_ARC)


func test_keystone_hidden_behind_wall() -> void:
	# A 3 x 4 wall of cubes right in front (+z) of a small cube at the back.
	var blocks: Array = []
	for y in 4:
		for x in [-1.0, 0.0, 1.0]:
			blocks.append(_b("c%d_%d" % [y, x + 1], "cube", x, y, 0.8))
	blocks.append(_b("k", "cube", 0, 0, -0.8, "crystal_amber"))
	var r := KeystoneCheck.check(_lv(blocks, ["k"], 6.0, 5.0))
	assert_false(r["ok"])
	assert_lt(float(r["keystones"]["k"]["visible_ratio"]), 0.3)


func test_lob_over_low_wall() -> void:
	# Low wall in front: the arc of tap_target hits the wall, a high drag_release shot clears it.
	var blocks: Array = [_b("k", "pillar_3", 0, 0, -1.5, "crystal_amber")]
	for x in [-1.0, 0.0, 1.0]:
		blocks.append(_b("w%d" % (x + 1), "cube", x, 0, 0.5))
	var r := KeystoneCheck.check(_lv(blocks, ["k"], 6.0, 5.0))
	assert_true(r["keystones"]["k"]["reachable"], "; ".join(r["issues"]))


func test_layout_flags() -> void:
	var ok := LayoutCheck.check(_lv([_b("k", "cube", 0, 0, 0, "crystal_amber")], ["k"]))
	assert_true(ok["ok"], "; ".join(ok["issues"]))
	var bad := LayoutCheck.check(_lv([_b("k", "cube", 2.7, 0, 0)], []))
	assert_eq(bad["issues"].size(), 3, "; ".join(bad["issues"]))  # edge, no keystone, no crystal


func test_platform_for() -> void:
	var p := LayoutCheck.platform_for([_b("a", "cube", -1, 0, 0), _b("b", "cube", 1, 0, 0)])
	var pad := float(GameConfig.rule("physics.spawn_edge_inset")) + float(GameConfig.rule("generator.platform_margin"))
	assert_almost_eq(float(p["width"]), 3.0 + 2.0 * pad, 0.01)
	assert_almost_eq(float(p["depth"]), 1.0 + 2.0 * pad, 0.01)
