class_name StressLevel
extends RefCounted
## Dev-only performance test level (S-008, Faz 1 Step 13, P key): rules.dev.stress_block_count
## unit cubes in a stress_columns (x) x stress_rows (z) grid, stacked layer by layer, materials
## cycling through the start world's palette. Built as a normal level dictionary so the regular
## TowerBuilder / referee / HUD run unchanged.

const STRESS_LEVEL_ID := "dev_stress"
## Cube = 1 m unit (shapes.json "cube"); the grid uses its footprint as spacing.
const CUBE_SHAPE := "cube"


static func build() -> Dictionary:
	var count := int(GameConfig.rule("dev.stress_block_count"))
	var cols := int(GameConfig.rule("dev.stress_columns"))
	var rows := int(GameConfig.rule("dev.stress_rows"))
	var inset := float(GameConfig.rule("physics.spawn_edge_inset"))
	var cube_size := ShapeBuilder.to_vec3(GameConfig.shape(CUBE_SHAPE)["size"])
	var start_level := GameConfig.level(str(GameConfig.rule("dev.start_level_id")))
	var palette: Array = (GameConfig.world(str(start_level.get("world"))).get("palette", {}) as Dictionary).keys()
	var blocks: Array = []
	for i in count:
		var layer := i / (cols * rows)
		var cell := i % (cols * rows)
		var cx := cell % cols
		var cz := cell / cols
		blocks.append({
			"id": "s%03d" % (i + 1),
			"shape": CUBE_SHAPE,
			"mat": palette[i % palette.size()],
			"x": (cx - (cols - 1) / 2.0) * cube_size.x,
			"y": layer * cube_size.y,
			"z": (cz - (rows - 1) / 2.0) * cube_size.z,
			"rot": [0, 0, 0],
		})
	return {
		"id": STRESS_LEVEL_ID,
		"index": 0,
		"shots": int(GameConfig.rule("shots.default_per_level")),
		"objective": {"type": str(GameConfig.rule("objective_defaults.type"))},
		"platform": {
			"width": cols * cube_size.x + inset * 2.0,
			"depth": rows * cube_size.z + inset * 2.0,
		},
		"blocks": blocks,
		"cores": [],
		"keystones": [],
		"baked": true,
	}
