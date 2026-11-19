class_name MaterialPicker
extends RefCounted
## Materials for a template's blocks (docs/03 §6.3, K-022). Templates give roles; assign() turns
## them into material ids, for one structure at a time:
##  1. Palette split: crystals = "shatter" flag; solids split into heavy / light around the mean
##     density of the palette's solids (Akdeniz: stone heavy, wood light). Picks are weighted by
##     the palette weights (worlds.json).
##  2. crystal role -> a palette crystal.
##  3. heavy_ratio (difficulty curve) of the non-crystal blocks become heavy: structure-role blocks
##     first, then the others from the bottom up ("sütunlar/temeller ağır; üst katlar hafif");
##     the rest are light. Blocks with "keep_role" (e.g. dominoes) keep their own role's class.
##  4. Level role overrides (difficulty.role_overrides): crystal_ratio_min (breather) turns the
##     highest light blocks into crystals until the share is reached.
##  5. Intro ball (level.intro_ball, or the ball whose tutorial_level_id is this level): at least
##     difficulty.intro_ball.strong_material_share of the non-crystal blocks are made of materials
##     the ball is strong against (balls.json damage_mult > 1), light/top blocks first.
##  Mirror pairs always share a material (_sync_mirrors after steps 3–5).
##  6. Keystones must stand out: a keystone made of the tower's most common material gets another
##     solid material (a crystal only if the palette has no other solid and the block may shatter).
## Blocks that already have "mat" are left alone.

const SHATTER_FLAG := "shatter"
const JOINT_FLAG := "joint"


## ctx: {"level_role": String, "intro_ball": String} (LevelExpander.material_context()).
static func assign(blocks: Array, keystones: Array, world: Dictionary, p: Dictionary, ctx: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var palette: Dictionary = world.get("palette", {})
	var crystals := {}
	var heavy := {}
	var light := {}
	_split(palette, crystals, heavy, light)

	var free: Array = []  # non-crystal blocks whose material we choose
	for b: Dictionary in blocks:
		if b.has("mat"):
			continue
		if str(b.get("role", "")) == TowerTemplate.ROLE_CRYSTAL:
			b["mat"] = _pick(crystals if not crystals.is_empty() else light, rng)
		else:
			free.append(b)

	# 3. heavy_ratio, structure first, then bottom-up. keep_role blocks follow their role.
	var ordered := free.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := str(a.get("role")) == TowerTemplate.ROLE_STRUCTURE
		var sb := str(b.get("role")) == TowerTemplate.ROLE_STRUCTURE
		if sa != sb:
			return sa
		return float(a["y"]) < float(b["y"]))
	var n_heavy := roundi(float(p.get("heavy_ratio", 0.0)) * ordered.size())
	var given := 0
	for b: Dictionary in ordered:
		var want_heavy: bool
		if bool(b.get("keep_role", false)):
			want_heavy = str(b.get("role")) == TowerTemplate.ROLE_STRUCTURE
		else:
			want_heavy = given < n_heavy
		if want_heavy:
			given += 1
		b["mat"] = _pick(heavy if want_heavy and not heavy.is_empty() else (light if not light.is_empty() else heavy), rng)
	_sync_mirrors(blocks, keystones, heavy)

	# 4. crystal_ratio_min from the level role.
	var overrides: Dictionary = (GameConfig.difficulty().get("role_overrides", {}) as Dictionary).get(str(ctx.get("level_role", "")), {})
	var min_crystal := float(overrides.get("crystal_ratio_min", 0.0))
	if min_crystal > 0.0 and not crystals.is_empty():
		var tops := _non_key(free, keystones)
		tops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) > float(b["y"]))
		for b: Dictionary in tops:
			if crystal_share(blocks) >= min_crystal:
				break
			if not bool(b.get("keep_role", false)):
				b["mat"] = _pick(crystals, rng)
		_sync_mirrors(blocks, keystones, crystals)

	# 5. Intro ball: strong materials.
	var strong := strong_materials(str(ctx.get("intro_ball", "")), palette)
	if not strong.is_empty():
		var share := float(GameConfig.difficulty().get("intro_ball", {}).get("strong_material_share", 0.0))
		var solids := _non_crystal(blocks)
		var need := ceili(share * solids.size())
		var have := 0
		for b: Dictionary in solids:
			if strong.has(b["mat"]):
				have += 1
		var candidates := _non_key(solids, keystones)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var la := str(a.get("role")) != TowerTemplate.ROLE_STRUCTURE
			var lb := str(b.get("role")) != TowerTemplate.ROLE_STRUCTURE
			if la != lb:
				return la
			return float(a["y"]) > float(b["y"]))
		for b: Dictionary in candidates:
			if have >= need:
				break
			if not strong.has(b["mat"]):
				b["mat"] = _pick(strong, rng)
				have += 1
		_sync_mirrors(blocks, keystones, strong)

	# 6. Keystones stand out from the most common material.
	var common := most_common(blocks)
	for b: Dictionary in blocks:
		if keystones.has(b.get("id")) and b["mat"] == common:
			# Another solid first (a toppling keystone such as a domino must not shatter);
			# a crystal only when the palette has no other solid.
			var others := {}
			for pool: Dictionary in [heavy, light]:
				for m: String in pool:
					if m != common:
						others[m] = pool[m]
			if others.is_empty() and not bool(b.get("keep_role", false)):
				others = crystals.duplicate()
			if not others.is_empty():
				b["mat"] = _pick(others, rng)


## Mirror pairs (same shape, role, height, |x| and z; not keystones) get the same material, so
## symmetric towers stay balanced: a stone load on one end of a chord and wood on the other tips
## a chord balanced on one post. A mixed pair takes a material from `prefer` when it has one,
## else the material of its first block.
static func _sync_mirrors(blocks: Array, keystones: Array, prefer: Dictionary) -> void:
	var groups := {}
	for b: Dictionary in blocks:
		if keystones.has(b.get("id")) or not b.has("mat"):
			continue
		var key := "%s|%s|%s|%.2f|%.2f|%.2f" % [b["shape"], b.get("role", ""), b.get("keep_role", false),
				float(b["y"]), absf(float(b["x"])), float(b["z"])]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(b)
	for key: String in groups:
		var g: Array = groups[key]
		if g.size() < 2:
			continue
		var mat := str(g[0]["mat"])
		for b: Dictionary in g:
			if prefer.has(b["mat"]):
				mat = str(b["mat"])
				break
		for b: Dictionary in g:
			b["mat"] = mat


## Materials the ball is strong against (damage_mult > 1): palette ones, else any breakable
## non-joint material. {} when there is no such ball.
static func strong_materials(ball_id: String, palette: Dictionary) -> Dictionary:
	if ball_id.is_empty():
		return {}
	var out := {}
	var mult: Dictionary = GameConfig.ball(ball_id).get("damage_mult", {})
	for m: String in mult:
		if float(mult[m]) > 1.0 and palette.has(m):
			out[m] = float(palette[m])
	if out.is_empty():
		for m: String in mult:
			var flags: Array = GameConfig.material(m).get("flags", [])
			if float(mult[m]) > 1.0 and not flags.has(JOINT_FLAG) and not flags.has(SHATTER_FLAG):
				out[m] = 1.0
	return out


static func crystal_share(blocks: Array) -> float:
	if blocks.is_empty():
		return 0.0
	var n := 0
	for b: Dictionary in blocks:
		if _shatters(str(b.get("mat", ""))):
			n += 1
	return float(n) / blocks.size()


static func most_common(blocks: Array) -> String:
	var count := {}
	for b: Dictionary in blocks:
		count[b["mat"]] = int(count.get(b["mat"], 0)) + 1
	var best := ""
	for m: String in count:
		if best.is_empty() or int(count[m]) > int(count[best]):
			best = m
	return best


static func _split(palette: Dictionary, crystals: Dictionary, heavy: Dictionary, light: Dictionary) -> void:
	var solids := {}
	for m: String in palette:
		if _shatters(m):
			crystals[m] = float(palette[m])
		else:
			solids[m] = float(palette[m])
	var mean := 0.0
	for m: String in solids:
		mean += _density(m)
	mean /= maxf(1.0, solids.size())
	for m: String in solids:
		if _density(m) >= mean:
			heavy[m] = solids[m]
		else:
			light[m] = solids[m]


## Weighted random pick (weights = palette shares). Sorted keys keep it deterministic per seed.
static func _pick(pool: Dictionary, rng: RandomNumberGenerator) -> String:
	var keys := PackedStringArray(pool.keys())
	keys.sort()
	if keys.is_empty():
		return ""
	var total := 0.0
	for k in keys:
		total += float(pool[k])
	var r := rng.randf() * total
	for k in keys:
		r -= float(pool[k])
		if r <= 0.0:
			return k
	return keys[-1]


static func _non_crystal(blocks: Array) -> Array:
	return blocks.filter(func(b: Dictionary) -> bool: return not _shatters(str(b.get("mat", ""))))


static func _non_key(blocks: Array, keystones: Array) -> Array:
	return blocks.filter(func(b: Dictionary) -> bool: return not keystones.has(b.get("id")))


static func _shatters(mat: String) -> bool:
	return (GameConfig.material(mat).get("flags", []) as Array).has(SHATTER_FLAG)


static func _density(mat: String) -> float:
	return float(GameConfig.material(mat).get("density", 0.0))
