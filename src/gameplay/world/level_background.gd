class_name LevelBackground
extends Node
## World backdrop (Faz 7, docs/04 §3.0, K-035): the world's far + front images as two layers BEHIND
## the 3D scene (the environment draws canvas layers <= -1 as background). Each fills the screen
## height and is centred, so tall phones crop the sides (the art keeps its identity inside).
## Also applies the world's Environment and sun colour. Missing files = grey-box look.

const FAR_LAYER := -10
const FRONT_LAYER := -9


func setup(world: Dictionary, env_node: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var dir := str(world.get("background_dir", ""))
	var added := 0
	for pair in [[str(GameConfig.rule("visuals.background_far")), FAR_LAYER],
			[str(GameConfig.rule("visuals.background_front")), FRONT_LAYER]]:
		var path := dir + str(pair[0])
		if dir.is_empty() or str(pair[0]).is_empty() or not ResourceLoader.exists(path):
			continue
		var layer := CanvasLayer.new()
		layer.layer = int(pair[1])
		var rect := TextureRect.new()
		rect.texture = load(path)
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		add_child(layer)
		added += 1
	var env_path := str(world.get("environment", ""))
	if added > 0 and ResourceLoader.exists(env_path):
		env_node.environment = load(env_path)
	var light: Dictionary = world.get("light", {})
	if not light.is_empty():
		sun.light_color = Color(float(light["color"][0]), float(light["color"][1]), float(light["color"][2]))
		sun.light_energy = float(light.get("energy", sun.light_energy))
