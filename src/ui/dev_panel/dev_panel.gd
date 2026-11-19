class_name DevPanel
extends CanvasLayer
## Hidden live-tuning panel (docs/02 §5.3, Faz 1 Step 11). F1 or rules.dev.panel_open_touches
## fingers toggles it; debug builds only. Sliders come from rules.dev.panel and change GameConfig
## in memory: they survive a level restart (R) but are gone when the game is closed.
## "JSON'a kaydet" (only when run from the editor; res:// is read-only in an export) writes the
## changed numbers back into game_data/*.json in place, keeping formatting and "_doc" keys.
## Entries with "restart": true (marked ↻) only take effect when the level restarts.

## Dev UI layout (visual only, not game rules).
## Full-width strip in the empty sky above the tower (scrolls), so the tower stays clickable.
const PANEL_SIDE_MARGIN := 16.0
const PANEL_TOP := 190.0
const PANEL_HEIGHT := 760.0
const FONT_SIZE := 28
const TITLE_FONT_SIZE := 34
const ROW_SPACING := 6
const SLIDER_HEIGHT := 44.0
const BUTTON_HEIGHT := 64.0
const PANEL_COLOR := Color(0.08, 0.09, 0.12, 0.88)
const PANEL_CORNER_RADIUS := 12
const PANEL_PADDING := 18.0
## Drawn above the HUD.
const CANVAS_LAYER := 10
const RESTART_MARK := " ↻"
const SAVED_COLOR := Color(0.5, 1.0, 0.5)
const ERROR_COLOR := Color(1.0, 0.45, 0.4)
const INFO_COLOR := Color(0.85, 0.85, 0.85)

## Open/closed survives a level restart (the panel is part of level.tscn).
static var _open: bool = false

var _entries: Array[Dictionary] = []
var _value_labels: Array[Label] = []
var _sliders: Array[HSlider] = []
var _status: Label
var _root: PanelContainer
var _touches: Dictionary = {}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = CANVAS_LAYER
	for entry: Dictionary in GameConfig.rule("dev.panel"):
		_entries.append(entry)
	_build()
	_root.visible = _open


func is_open() -> bool:
	return _root != null and _root.visible


func toggle() -> void:
	_open = not _open
	_root.visible = _open


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_touches[touch.index] = true
			if _touches.size() >= int(GameConfig.rule("dev.panel_open_touches")):
				_touches.clear()
				toggle()
		else:
			_touches.erase(touch.index)


func _build() -> void:
	_root = PanelContainer.new()
	_root.anchor_right = 1.0
	_root.offset_left = PANEL_SIDE_MARGIN
	_root.offset_right = -PANEL_SIDE_MARGIN
	_root.offset_top = PANEL_TOP
	_root.offset_bottom = PANEL_TOP + PANEL_HEIGHT
	var bg := StyleBoxFlat.new()
	bg.bg_color = PANEL_COLOR
	bg.set_corner_radius_all(PANEL_CORNER_RADIUS)
	bg.set_content_margin_all(PANEL_PADDING)
	_root.add_theme_stylebox_override("panel", bg)
	add_child(_root)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ROW_SPACING)
	scroll.add_child(list)

	var title := _label("DEV PANEL  (F1 kapat)", TITLE_FONT_SIZE)
	list.add_child(title)
	for i in _entries.size():
		var entry := _entries[i]
		var value_label := _label("", FONT_SIZE)
		list.add_child(value_label)
		_value_labels.append(value_label)
		var slider := HSlider.new()
		slider.min_value = float(entry["min"])
		slider.max_value = float(entry["max"])
		slider.step = float(entry["step"])
		slider.custom_minimum_size.y = SLIDER_HEIGHT
		slider.focus_mode = Control.FOCUS_NONE  # keep Space/arrows for the dev keys
		slider.value = GameConfig.dev_get(entry)
		slider.value_changed.connect(_on_slider_changed.bind(i))
		list.add_child(slider)
		_sliders.append(slider)
		_refresh_label(i)

	list.add_child(_button("Bölümü yeniden başlat (R)", _restart))
	list.add_child(_button("JSON değerlerine dön", _revert))
	if OS.has_feature("editor"):
		list.add_child(_button("JSON'a kaydet", _save))
	list.add_child(_label("↻ = bölüm yeniden başlayınca uygulanır", FONT_SIZE))
	_status = _label("", FONT_SIZE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_status)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = BUTTON_HEIGHT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	return b


func _on_slider_changed(value: float, index: int) -> void:
	GameConfig.dev_set(_entries[index], value)
	_refresh_label(index)


func _refresh_label(index: int) -> void:
	var entry := _entries[index]
	var mark := RESTART_MARK if entry.get("restart", false) else ""
	var decimals := JsonPatcher.decimals_for(float(entry["step"]))
	_value_labels[index].text = "%s%s: %s" % [entry["label"], mark,
			JsonPatcher.format_number(GameConfig.dev_get(entry), decimals)]


func _restart() -> void:
	get_tree().reload_current_scene()


func _revert() -> void:
	GameConfig.load_all()
	GameConfig.apply_physics_settings()
	_restart()


## Writes every changed entry back to its JSON file. Nothing is written if any patch fails.
func _save() -> void:
	var changed := GameConfig.dev_changed_labels()
	if changed.is_empty():
		_set_status("Değişiklik yok.", INFO_COLOR)
		return
	var texts: Dictionary = {}  # file path -> patched text
	for entry in _entries:
		if not changed.has(str(entry["label"])):
			continue
		var path := GameConfig.dev_file_path(entry)
		if not texts.has(path):
			texts[path] = FileAccess.get_file_as_string(path)
		var decimals := JsonPatcher.decimals_for(float(entry["step"]))
		for json_path in _json_paths(entry):
			var patched := JsonPatcher.set_number(texts[path], json_path, GameConfig.dev_get(entry), decimals)
			if patched.is_empty():
				_set_status("HATA: %s yazılamadı (%s). Hiçbir dosya değişmedi." % [entry["label"], path], ERROR_COLOR)
				return
			texts[path] = patched
	for path: String in texts:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			_set_status("HATA: %s açılamadı (%s)." % [path, error_string(FileAccess.get_open_error())], ERROR_COLOR)
			return
		f.store_string(texts[path])
		f.close()
	GameConfig.load_all()  # the files are now the new baseline
	_set_status("Kaydedildi: %s\nDosyalar: %s\nClaude'a söyle: doğrulayıcı çalıştırılsın + commit." % [
			", ".join(changed), ", ".join(PackedStringArray(texts.keys()))], SAVED_COLOR)


## Text paths inside the JSON file for one panel entry (one per id).
func _json_paths(entry: Dictionary) -> Array[Array]:
	var key_parts: Array = Array(str(entry["key"]).split("."))
	var out: Array[Array] = []
	match str(entry["file"]):
		"rules":
			out.append(key_parts)
		"materials":
			for id: String in entry.get("ids", []):
				out.append((["materials", id] as Array) + key_parts)
		"balls":
			for id: String in entry.get("ids", []):
				out.append((["balls", {"id": id}] as Array) + key_parts)
	return out


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
