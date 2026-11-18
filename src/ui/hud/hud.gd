class_name Hud
extends CanvasLayer
## In-game HUD (docs/01 §3.1, docs/07 §3, K-018). Grey-box version: level label, shot pips,
## clear-progress bar with target marker, result banner, jackpot banner, dev info line.
## Driven only by EventBus signals; player-facing text is Turkish.

const SHOT_FULL := "●"
const SHOT_EMPTY := "○"
const STAR_FULL := "★"
const STAR_EMPTY := "☆"
const MAX_STARS := 3
const OBJ_CLEAR_PERCENT := "clear_percent"
## Grey-box colours (Faz 7 UI kit replaces them).
const BAR_BG_COLOR := Color(0.0, 0.0, 0.0, 0.45)
const BAR_FILL_COLOR := Color(0.95, 0.95, 0.95)
const BAR_DONE_COLOR := Color(1.0, 0.8, 0.2)
const BAR_CORNER_RADIUS := 10

var _objective: String = ""
var _target: float = 0.0
var _fill_style: StyleBoxFlat

@onready var _level_label: Label = $Top/LevelLabel
@onready var _shots: Label = $Top/ShotsLabel
@onready var _bar: ProgressBar = $Top/ClearBar
@onready var _marker: ColorRect = $Top/ClearBar/TargetMarker
@onready var _percent: Label = $Top/ClearBar/PercentLabel
@onready var _banner: Label = $Banner
@onready var _sub_banner: Label = $SubBanner
@onready var _jackpot: Label = $Jackpot
@onready var _dev: Label = $DevInfo


func _ready() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG_COLOR
	bg.set_corner_radius_all(BAR_CORNER_RADIUS)
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = BAR_FILL_COLOR
	_fill_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", _fill_style)
	_bar.resized.connect(_place_marker)
	_banner.visible = false
	_sub_banner.visible = false
	_jackpot.visible = false
	EventBus.shots_changed.connect(_on_shots_changed)
	EventBus.clear_progress_changed.connect(_on_clear_progress)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.level_failed.connect(_on_level_failed)
	EventBus.core_dropped.connect(_on_core_dropped)


func setup(level_index: int, objective_type: String) -> void:
	_level_label.text = "BÖLÜM %d" % level_index
	_objective = objective_type
	_bar.visible = objective_type == OBJ_CLEAR_PERCENT


func set_dev_text(text: String) -> void:
	_dev.text = text


func _on_shots_changed(left: int, total: int) -> void:
	var pips: PackedStringArray = []
	for i in total:
		pips.append(SHOT_FULL if i < left else SHOT_EMPTY)
	_shots.text = " ".join(pips)


func _on_clear_progress(ratio: float, target: float) -> void:
	_target = target
	_bar.value = ratio * _bar.max_value
	_percent.text = "%%%d / %%%d" % [roundi(ratio * 100.0), roundi(target * 100.0)]
	_fill_style.bg_color = BAR_DONE_COLOR if ratio >= target else BAR_FILL_COLOR
	_place_marker()


func _place_marker() -> void:
	_marker.position.x = _bar.size.x * _target - _marker.size.x / 2.0


func _on_level_completed(stars: int, _shots_left: int) -> void:
	_show_banner("KAZANDIN!", STAR_FULL.repeat(stars) + STAR_EMPTY.repeat(MAX_STARS - stars) + "\nR: tekrar")


func _on_level_failed() -> void:
	_show_banner("KAYBETTİN", "Gülle bitti · R: tekrar")


func _on_core_dropped(_core: Node3D) -> void:
	if _objective == OBJ_CLEAR_PERCENT:
		var gold := int(GameConfig.economy().get("rewards", {}).get("core_jackpot_gold", 0))
		_jackpot.text = "JACKPOT!\n+%d altın" % gold
	else:
		_jackpot.text = "KÜRE DÜŞTÜ!"
	_jackpot.visible = true


func _show_banner(title: String, subtitle: String) -> void:
	_banner.text = title
	_sub_banner.text = subtitle
	_banner.visible = true
	_sub_banner.visible = true
