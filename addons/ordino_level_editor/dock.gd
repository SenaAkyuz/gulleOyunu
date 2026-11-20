@tool
extends VBoxContainer
## The Ordino level editor dock (Step 10, docs/03 §8.2, K-024):
##   Dünya / Bölüm seç · rol, zorluk, kaynak · seed, şablon
##   Aç       — level file or generator result into the preview scene
##   Üret     — LevelGenerator with the seed / template (all checks) into the preview
##   5 Aday   — candidate pipeline for the level (table + screenshots), "Önizle" loads one
##   Simüle Et — LevelSim on the preview (current block positions)
##   Test Et  — plays level.tscn with the preview (test save, never the player's save)
##   Kaydet   — writes the preview as a baked level JSON (asks before overwriting a file)
## The preview scene res://_editor/level_preview.tscn (git-ignored) holds one StaticBody3D per
## block (LevelPreview); move / rotate them with Godot's own gizmo. The editor runs no physics
## and no autoloads, so generation / simulation run in a headless background Godot
## (editor_cli.gd, candidates_cli.gd) and their JSON output is read back.

const PREVIEW_SCENE := "res://_editor/level_preview.tscn"
const WORK_DIR := "user://editor/"
const TEST_LEVEL := "user://editor/test_level.json"
const LEVEL_SCENE := "res://src/gameplay/level/level.tscn"
const DATA_DIR := "res://game_data/"
const EDITOR_CLI := "src/tools/sim/editor_cli.gd"
const CANDIDATES_CLI := "src/tools/sim/candidates_cli.gd"
const CANDIDATES_DIR := "res://_candidates/"
const POLL_SEC := 0.5
const THUMB_SIZE := Vector2(120, 213)
const RUN_ARGS_SETTING := "editor/run/main_run_args"
const TEST_ARG := "++ --editor-test-level"
const RESTORE_ARGS_SEC := 2.0

var _worlds: Array = []
var _data: Dictionary = {}
var _world: OptionButton
var _level: OptionButton
var _info: Label
var _seed: SpinBox
var _template: OptionButton
var _status: Label
var _results: VBoxContainer
var _timer: Timer
var _job: Dictionary = {}  # {kind, out, started}
var _confirm: ConfirmationDialog


func _ready() -> void:
	_load_data()
	add_child(_title("Ordino Bölüm Editörü"))
	var row := HBoxContainer.new()
	_world = OptionButton.new()
	for w: Dictionary in _worlds:
		_world.add_item("%d · %s" % [int(w["index"]), w.get("name_tr", w["id"])])
	_world.item_selected.connect(func(_i: int) -> void: _fill_levels())
	row.add_child(_world)
	_level = OptionButton.new()
	_level.item_selected.connect(func(_i: int) -> void: _refresh_info())
	row.add_child(_level)
	add_child(row)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	var row2 := HBoxContainer.new()
	row2.add_child(_label("Seed"))
	_seed = SpinBox.new()
	_seed.max_value = 99999999
	_seed.value = float(_data.get("rules", {}).get("generator", {}).get("base_seed", 1000))
	row2.add_child(_seed)
	_template = OptionButton.new()
	row2.add_child(_template)
	add_child(row2)
	var grid := GridContainer.new()
	grid.columns = 3
	for b in [["Aç", _on_open], ["Üret", _on_generate], ["5 Aday", _on_candidates],
			["Simüle Et", _on_simulate], ["Test Et", _on_test], ["Kaydet (JSON)", _on_save]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		grid.add_child(btn)
	add_child(grid)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 300
	_results = VBoxContainer.new()
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_results)
	add_child(scroll)
	_timer = Timer.new()
	_timer.wait_time = POLL_SEC
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_save_confirmed)
	add_child(_confirm)
	_fill_levels()


# --- Data (the editor has no autoloads: read game_data directly) ---

func _load_data() -> void:
	_data = {"rules": _json("rules.json"), "shapes": {}, "difficulty": _json("difficulty.json")}
	var shapes: Dictionary = _json("shapes.json")
	_data["shapes"] = shapes.get("shapes", shapes)
	var worlds: Dictionary = _json("worlds.json")
	_worlds = worlds.get("worlds", [])


func _json(file: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + file))
	return parsed if parsed is Dictionary else {}


func _world_data() -> Dictionary:
	return _worlds[_world.selected] if _world.selected >= 0 and _world.selected < _worlds.size() else {}


func _level_id() -> String:
	return "w%02d_l%02d" % [int(_world_data().get("index", 1)), _level.selected + 1]


func _level_path() -> String:
	var w := _world_data()
	return DATA_DIR + "levels/w%02d_%s/%s.json" % [int(w.get("index", 1)), w.get("id", ""), _level_id()]


func _fill_levels() -> void:
	_level.clear()
	for k in range(1, int(_world_data().get("level_count", 10)) + 1):
		_level.add_item("L%02d" % k)
	_template.clear()
	_template.add_item("plan")
	for t in _world_data().get("allowed_templates", []):
		_template.add_item(str(t))
	_refresh_info()


func _refresh_info() -> void:
	var k := _level.selected + 1
	var rhythm: Array = _data["difficulty"].get("rhythm", [])
	var role := str(rhythm[k - 1]["role"]) if k - 1 < rhythm.size() else "?"
	var base: Dictionary = _data["difficulty"].get("world_base", {})
	var offset := float(rhythm[k - 1]["offset"]) if k - 1 < rhythm.size() else 0.0
	var d := clampf((float(base.get("start", 8)) + (int(_world_data().get("index", 1)) - 1) * float(base.get("step_per_world", 10)) + offset)
			* float(_data["difficulty"].get("global_multiplier", 1.0)), 1.0, 100.0)
	var handmade: Array = _data["difficulty"].get("handmade_levels", [])
	var src := "dosya" if FileAccess.file_exists(_level_path()) else ("elle tasarlanacak (aday)" if handmade.has(float(k)) or handmade.has(k) else "generator")
	_info.text = "%s · rol %s · zorluk %.0f · kaynak: %s" % [_level_id(), role, d, src]


# --- Buttons ---

func _on_open() -> void:
	_run_cli("expand", ["--mode", "expand", "--level", _level_id()])


func _on_generate() -> void:
	var args := ["--mode", "generate", "--level", _level_id(), "--seed", str(int(_seed.value))]
	if _template.selected > 0:
		args.append_array(["--template", _template.get_item_text(_template.selected)])
	_run_cli("generate", args)


func _on_candidates() -> void:
	# Windowed (not headless) so the pipeline can take screenshots of every candidate.
	_start_job("candidates", CANDIDATES_DIR + _level_id() + "/cand_1.json",
			["--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "-s", CANDIDATES_CLI, "--", "--level", _level_id()],
			true)


func _on_simulate() -> void:
	var lv := _preview_level()
	if lv.is_empty():
		return
	var file := WORK_DIR + "sim_in.json"
	_write(file, lv)
	_run_cli("sim", ["--mode", "sim", "--file", ProjectSettings.globalize_path(file)])


func _on_test() -> void:
	var lv := _preview_level()
	if lv.is_empty():
		return
	_write(TEST_LEVEL, lv)
	var old: Variant = ProjectSettings.get_setting(RUN_ARGS_SETTING, "")
	ProjectSettings.set_setting(RUN_ARGS_SETTING, TEST_ARG)
	EditorInterface.play_custom_scene(LEVEL_SCENE)
	# The game starts a moment later: restore the run arguments after it has launched.
	await get_tree().create_timer(RESTORE_ARGS_SEC).timeout
	ProjectSettings.set_setting(RUN_ARGS_SETTING, old)
	_status.text = "Test Et: oyun açıldı (test kaydı kullanılır, gerçek kayda dokunulmaz)."


func _on_save() -> void:
	if _preview_level().is_empty():
		return
	if FileAccess.file_exists(_level_path()):
		_confirm.dialog_text = "%s dosyası var. Üzerine yazılsın mı?" % _level_path()
		_confirm.popup_centered()
	else:
		_save_confirmed()


func _save_confirmed() -> void:
	var lv := _preview_level()
	lv["baked"] = true
	lv.erase("generated")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_level_path().get_base_dir()))
	_write(_level_path(), lv)
	_status.text = "Kaydedildi: %s\nClaude'a söyle: doğrulayıcı (python tools/validate_game_data.py) + commit." % _level_path()
	EditorInterface.get_resource_filesystem().scan()
	_refresh_info()


# --- Background jobs ---

func _run_cli(kind: String, args: Array) -> void:
	var out := WORK_DIR + kind + "_out.json"
	var full := ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "-s", EDITOR_CLI, "--"]
	full.append_array(args)
	full.append_array(["--out", ProjectSettings.globalize_path(out)])
	_start_job(kind, out, full, false)


func _start_job(kind: String, out: String, args: Array, _windowed: bool) -> void:
	if not _job.is_empty():
		_status.text = "Önceki iş sürüyor: %s" % _job["kind"]
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_DIR))
	var abs_out := ProjectSettings.globalize_path(out)
	if FileAccess.file_exists(abs_out):
		DirAccess.remove_absolute(abs_out)
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		_status.text = "Arka plan süreci başlatılamadı."
		return
	_job = {"kind": kind, "out": abs_out, "started": Time.get_ticks_msec(), "pid": pid}
	_status.text = "%s çalışıyor (arka planda)..." % kind
	_timer.start()


func _poll() -> void:
	if _job.is_empty():
		_timer.stop()
		return
	var secs := (Time.get_ticks_msec() - int(_job["started"])) / 1000.0
	if not FileAccess.file_exists(_job["out"]):
		if not OS.is_process_running(int(_job["pid"])):
			_status.text = "%s bitti ama sonuç yok (Output'a bak)." % _job["kind"]
			_job = {}
			_timer.stop()
		else:
			_status.text = "%s çalışıyor... %.0f sn" % [_job["kind"], secs]
		return
	if _job["kind"] == "candidates" and OS.is_process_running(int(_job["pid"])):
		_status.text = "5 Aday çalışıyor... %.0f sn" % secs
		return
	var kind: String = _job["kind"]
	var out: String = _job["out"]
	_job = {}
	_timer.stop()
	if kind == "candidates":
		_show_candidates()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out))
	if not (parsed is Dictionary):
		_status.text = "Sonuç okunamadı."
		return
	var res: Dictionary = parsed
	match kind:
		"expand", "generate":
			if not bool(res.get("ok", false)) or (res.get("level", {}) as Dictionary).is_empty():
				var r: Dictionary = res.get("report", {})
				_status.text = "%s geçmedi (%.0f sn): %s" % [kind, secs, "; ".join(PackedStringArray(r.get("last_problems", [res.get("error", "")])))]
				return
			_show_in_preview(res["level"])
			var rep: Dictionary = res.get("report", {})
			_status.text = "%s tamam (%.0f sn) · %s · deneme %s" % [kind, secs, "+".join(PackedStringArray(rep.get("templates", []))), rep.get("attempts", "-")]
		"sim":
			_show_sim(res.get("sim", {}), secs)


# --- Preview scene ---

func _show_in_preview(level: Dictionary) -> void:
	var root := _preview_root()
	if root == null:
		return
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	var built := LevelPreview.build(level, _data)
	root.set_meta(LevelPreview.META_HEADER, built.get_meta(LevelPreview.META_HEADER))
	for c in built.get_children():
		built.remove_child(c)
		root.add_child(c)
		_own(c, root)
	built.free()
	EditorInterface.mark_scene_as_unsaved()


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for c in node.get_children():
		_own(c, owner_node)


## The preview scene's root (opened / created on demand).
func _preview_root() -> Node3D:
	var edited := EditorInterface.get_edited_scene_root()
	if edited and edited.scene_file_path == PREVIEW_SCENE:
		return edited as Node3D
	if not FileAccess.file_exists(PREVIEW_SCENE):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_SCENE.get_base_dir()))
		var root := Node3D.new()
		root.name = LevelPreview.ROOT_NAME
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, PREVIEW_SCENE)
		root.free()
	EditorInterface.open_scene_from_path(PREVIEW_SCENE)
	var opened := EditorInterface.get_edited_scene_root()
	if opened == null or opened.scene_file_path != PREVIEW_SCENE:
		_status.text = "Önizleme sahnesi açılamadı; tekrar dene."
		return null
	return opened as Node3D


func _preview_level() -> Dictionary:
	var edited := EditorInterface.get_edited_scene_root()
	if edited == null or edited.scene_file_path != PREVIEW_SCENE or not edited.has_meta(LevelPreview.META_HEADER):
		_status.text = "Önce 'Aç', 'Üret' ya da bir adayı 'Önizle' ile önizleme sahnesine yükle."
		return {}
	return LevelPreview.read(edited as Node3D)


# --- Results ---

func _show_sim(sim: Dictionary, secs: float) -> void:
	_clear_results()
	if sim.is_empty():
		_status.text = "Simülasyon sonucu yok."
		return
	var lines := PackedStringArray(["Simülasyon (%.0f sn, %d örnek):" % [secs, int(sim.get("samples", 0))]])
	var v: Dictionary = sim.get("verdict", {})
	for m: String in v:
		lines.append("  %s: %s %s" % [m, str(v[m].get("value")), "✔" if bool(v[m].get("ok", false)) else "⚠"])
	lines.append("  jackpot %%%d · gülleyle çözüm %%%d" % [roundi(float(sim.get("jackpot_rate", 0)) * 100), roundi(float(sim.get("within_shots_rate", 0)) * 100)])
	_status.text = "\n".join(lines)


func _show_candidates() -> void:
	_clear_results()
	var dir := CANDIDATES_DIR + _level_id() + "/"
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if not (f.begins_with("cand_") and f.ends_with(".json")):
			continue
		n += 1
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
		if not (parsed is Dictionary):
			continue
		var c: Dictionary = parsed
		var row := HBoxContainer.new()
		var png := ProjectSettings.globalize_path(dir + f.get_basename() + ".png")
		if FileAccess.file_exists(png):
			var tex := TextureRect.new()
			tex.texture = ImageTexture.create_from_image(Image.load_from_file(png))
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = THUMB_SIZE
			row.add_child(tex)
		var info := Label.new()
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = _cand_text(c)
		row.add_child(info)
		if bool(c.get("ok", false)):
			var btn := Button.new()
			btn.text = "Önizle"
			var lv: Dictionary = c["level"]
			btn.pressed.connect(func() -> void: _show_in_preview(lv))
			row.add_child(btn)
		_results.add_child(row)
	_status.text = "%d aday (%s)" % [n, dir]


func _cand_text(c: Dictionary) -> String:
	if not bool(c.get("ok", false)):
		return "#%s %s seed %s — geçmedi" % [c.get("rank"), c.get("template"), c.get("seed")]
	var s: Dictionary = c["sim"]
	return "#%s %s seed %s\ntek atış %%%d · gülleyle %%%d · jackpot %%%d" % [c.get("rank"), c.get("template"), c.get("seed"),
			roundi(float(s["one_shot_solve_rate"]) * 100), roundi(float(s["within_shots_rate"]) * 100), roundi(float(s["jackpot_rate"]) * 100)]


func _clear_results() -> void:
	for c in _results.get_children():
		c.queue_free()


# --- Helpers ---

func _write(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _title(text: String) -> Label:
	var l := _label(text)
	l.add_theme_font_size_override("font_size", 18)
	return l


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l
