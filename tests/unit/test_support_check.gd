extends GutTest
## SupportCheck (docs/03 §4 rule 1): support polygon, load groups, rotated and tilted blocks,
## support_margin; plus the pre_settle physics confirmation.

var _id := 0


func _b(shape: String, x: float, y: float, z: float = 0.0, rot: Vector3 = Vector3.ZERO, mat: String = "stone") -> Dictionary:
	_id += 1
	return {"id": "t%02d" % _id, "shape": shape, "mat": mat, "x": x, "y": y, "z": z, "rot": [rot.x, rot.y, rot.z]}


func _lv(blocks: Array, cores: Array = [], w: float = 6.0, d: float = 4.0) -> Dictionary:
	return {"id": "test", "platform": {"width": w, "depth": d}, "blocks": blocks, "cores": cores}


func _reasons(r: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for i: Dictionary in r["issues"]:
		out.append(str(i["reason"]))
	return out


func before_each() -> void:
	_id = 0


func test_cube_on_platform() -> void:
	var r := SupportCheck.check(_lv([_b("cube", 0, 0)]))
	assert_true(r["ok"], SupportCheck.describe(r))
	assert_almost_eq(float(r["margins"]["t01"]), 0.5, 0.001)


func test_floating_cube_unsupported() -> void:
	var r := SupportCheck.check(_lv([_b("cube", 0, 0.5)]))
	assert_eq(_reasons(r), PackedStringArray([SupportCheck.REASON_UNSUPPORTED]))


func test_platform_edge() -> void:
	assert_true(SupportCheck.check(_lv([_b("cube", 2.4, 0)]))["ok"])
	assert_eq(_reasons(SupportCheck.check(_lv([_b("cube", 3.0, 0)]))), PackedStringArray([SupportCheck.REASON_MARGIN]))
	assert_eq(_reasons(SupportCheck.check(_lv([_b("cube", 3.2, 0)]))), PackedStringArray([SupportCheck.REASON_OUTSIDE]))


func test_offset_stack_and_margin() -> void:
	var ok := SupportCheck.check(_lv([_b("cube", 0, 0), _b("cube", 0.4, 1)]))
	assert_true(ok["ok"], SupportCheck.describe(ok))
	var tight := SupportCheck.check(_lv([_b("cube", 0, 0), _b("cube", 0.48, 1)]))
	assert_eq(_reasons(tight), PackedStringArray([SupportCheck.REASON_MARGIN]))


func test_load_of_everything_above_counts() -> void:
	# Each cube sits 0.35 further out: fine pair by pair, but middle + top together (COM 0.525)
	# overhang the bottom cube's top face (edge at 0.5).
	var r := SupportCheck.check(_lv([_b("cube", 0, 0), _b("cube", 0.35, 1), _b("cube", 0.7, 2)]))
	assert_false(r["ok"])
	assert_eq(r["issues"][0]["id"], "t02")
	assert_gt(float(r["margins"]["t03"]), 0.05, "üstteki küp tek başına dengede")


func test_plank_on_two_pillars_and_one() -> void:
	var two := SupportCheck.check(_lv([_b("pillar_2", -1.5, 0), _b("pillar_2", 1.5, 0), _b("plank_l", 0, 2, 0, Vector3.ZERO, "wood")]))
	assert_true(two["ok"], SupportCheck.describe(two))
	var one := SupportCheck.check(_lv([_b("pillar_2", -1.5, 0), _b("plank_l", 0, 2, 0, Vector3.ZERO, "wood")]))
	assert_false(one["ok"])


func test_crossed_planks() -> void:
	var r := SupportCheck.check(_lv([_b("plank_s", 0, 0), _b("plank_s", 0, 0.4, 0, Vector3(0, 90, 0))]))
	assert_true(r["ok"], SupportCheck.describe(r))
	# Overlap is the 0.9 x 0.9 square: the top plank's COM at its centre -> margin 0.45.
	assert_almost_eq(float(r["margins"]["t02"]), 0.45, 0.001)


func test_rotated_cube_on_cube() -> void:
	var r := SupportCheck.check(_lv([_b("cube", 0, 0), _b("cube", 0, 1, 0, Vector3(0, 45, 0))]))
	assert_true(r["ok"], SupportCheck.describe(r))


func test_cube_on_its_edge_is_a_line() -> void:
	# The contact is the edge line (a band of width ~support_contact_epsilon): never balanced.
	var r := SupportCheck.check(_lv([_b("cube", 0, sqrt(0.5) / 2.0, 0, Vector3(0, 0, 45))]))
	assert_false(r["ok"])
	assert_has([SupportCheck.REASON_LINE, SupportCheck.REASON_MARGIN], _reasons(r)[0])


func test_leaning_plank_on_cube_corner() -> void:
	# plank_s tilted 40°: lower edge on the platform, bottom face resting on the cube's top-left edge.
	var a := deg_to_rad(40.0)
	var h := sin(a)                               # plank origin height: lower bottom corner at y = 0
	var cube_left := (1.0 / sin(a) - 1.0) * cos(a)  # where the bottom face reaches y = 1
	var r := SupportCheck.check(_lv([
		_b("plank_s", 0, h, 0, Vector3(0, 0, 40), "wood"),
		_b("cube", cube_left + 0.5, 0)]))
	assert_true(r["ok"], SupportCheck.describe(r))
	var alone := SupportCheck.check(_lv([_b("plank_s", 0, h, 0, Vector3(0, 0, 40), "wood")]))
	assert_false(alone["ok"], "küp olmadan eğik kalas desteksiz")


func test_core_is_load_not_checked() -> void:
	# Core on the right end of a plank lying on one cube: the core's weight tips the plank.
	var no_core := SupportCheck.check(_lv([_b("cube", 0, 0), _b("plank_s", 0.3, 1, 0, Vector3.ZERO, "wood")]))
	assert_true(no_core["ok"], SupportCheck.describe(no_core))
	var with_core := SupportCheck.check(_lv([_b("cube", 0, 0), _b("plank_s", 0.3, 1, 0, Vector3.ZERO, "wood")],
			[{"x": 1.1, "y": 1.4, "z": 0}]))
	assert_false(with_core["ok"])
	assert_false((with_core["margins"] as Dictionary).has("core1"))


func test_level_01_is_balanced() -> void:
	var r := SupportCheck.check(GameConfig.level("w01_l01"))
	assert_true(r["ok"], SupportCheck.describe(r))


func test_physics_level_01_does_not_drift() -> void:
	var r: Dictionary = await SupportCheck.physics_drift(GameConfig.level("w01_l01"), self)
	assert_true(r["ok"], "en çok kayan %s: %.4f m" % [r["worst"], r["max_drift"]])


func test_physics_catches_overhang() -> void:
	var r: Dictionary = await SupportCheck.physics_drift(_lv([_b("cube", 0, 0), _b("cube", 0.75, 1)]), self)
	assert_false(r["ok"], "taşan küp kaymalı (%.4f m)" % r["max_drift"])
