extends GutTest
## Faz 3 Step 3: stack_pyramid + twin_pillars over their difficulty range (docs/03 §4).
## Each generated tower must: stay in the play area and edge inset, have a keystone and a crystal,
## pass the static balance check, have every keystone visible from the default camera and
## reachable from the cannon (docs/03 §4 rule 3, S-007), and not drift in the pre-settle physics run.

const Kit = preload("res://tests/helpers/template_kit.gd")
const DIFFICULTIES := [1.0, 15.0, 25.0]
const SEEDS := [1, 2, 3]
const TEMPLATES := ["stack_pyramid", "twin_pillars"]


func test_static_checks_over_range() -> void:
	for t: String in TEMPLATES:
		for d: float in DIFFICULTIES:
			for s: int in SEEDS:
				var lv := Kit.level(t, d, s)
				var bad := Kit.problems(lv)
				assert_eq(bad.size(), 0, "%s d=%d seed=%d: %s" % [t, d, s, "; ".join(bad)])


func test_block_count_follows_difficulty() -> void:
	for t: String in TEMPLATES:
		var small := (Kit.level(t, 1.0, 1)["blocks"] as Array).size()
		var big := (Kit.level(t, 25.0, 1)["blocks"] as Array).size()
		assert_gt(big, small, "%s: zorluk artınca blok sayısı artmalı (%d -> %d)" % [t, small, big])
		var budget := int(DifficultyCalc.params(25.0)["block_count"])
		assert_lte(big, budget + 2, "%s: bütçe %d, üretilen %d" % [t, budget, big])


func test_same_seed_same_tower() -> void:
	for t: String in TEMPLATES:
		assert_eq(Kit.level(t, 15.0, 7)["blocks"], Kit.level(t, 15.0, 7)["blocks"])


func test_physics_does_not_drift() -> void:
	for t: String in TEMPLATES:
		for d: float in DIFFICULTIES:
			var r: Dictionary = await SupportCheck.physics_drift(Kit.level(t, d, 1), self)
			assert_true(r["ok"], "%s d=%d: en çok kayan %s %.4f m" % [t, d, r["worst"], r["max_drift"]])
