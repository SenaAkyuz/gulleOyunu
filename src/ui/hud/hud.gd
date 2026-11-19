class_name Hud
extends CanvasLayer
## In-game HUD (docs/01 §3.1, docs/07 §3, K-018). Grey-box version: level label (+ best stars),
## gold balance, shot pips, clear-progress bar with target marker, result banner (+ gold earned),
## jackpot banner, dev info line.
## Driven only by EventBus signals; player-facing text is Turkish.

const SHOT_FULL := "●"
const SHOT_EMPTY := "○"
const STAR_FULL := "★"
const STAR_EMPTY := "☆"
const MAX_STARS := 3
const OBJ_CLEAR_PERCENT := "clear_percent"
const GOLD := "gold"
## Grey-box colours (Faz 7 UI kit replaces them).
const BAR_BG_COLOR := Color(0.0, 0.0, 0.0, 0.45)
const BAR_FILL_COLOR := Color(0.95, 0.95, 0.95)
const BAR_DONE_COLOR := Color(1.0, 0.8, 0.2)
const BAR_CORNER_RADIUS := 10
const PERF_OK_COLOR := Color(0.75, 1.0, 0.75)
const PERF_WARN_COLOR := Color(1.0, 0.35, 0.3)

var _objective: String = ""
var _target: float = 0.0
var _fill_style: StyleBoxFlat
## Win state of this attempt; _earned = gold of the win reward (EventBus.level_rewarded).
var _won: bool = false
var _win_stars: int = 0
var _earned: int = 0

@onready var _level_label: Label = $Top/LevelLabel
@onready var _shots: Label = $Top/ShotsLabel
@onready var _bar: ProgressBar = $Top/ClearBar
@onready var _marker: ColorRect = $Top/ClearBar/TargetMarker
@onready var _percent: Label = $Top/ClearBar/PercentLabel
@onready var _banner: Label = $Banner
@onready var _sub_banner: Label = $SubBanner
@onready var _jackpot: Label = $Jackpot
@onready var _dev: Label = $DevInfo
@onready var _perf: Label = $Top/PerfLabel
@onready var _gold: Label = $Top/GoldLabel


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
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.level_rewarded.connect(_on_level_rewarded)
	_set_gold(Economy.balance())


## best_stars: saved best result of this level (Progress); 0 = not cleared yet.
func setup(level_index: int, objective_type: String, best_stars: int = 0) -> void:
	_level_label.text = "BÖLÜM %d" % level_index
	if best_stars > 0:
		_level_label.text += "  " + _stars_text(best_stars)
	_objective = objective_type
	_bar.visible = objective_type == OBJ_CLEAR_PERCENT


func set_dev_text(text: String) -> void:
	_dev.text = text


## Dev performance line (S-008): red when FPS < rules.dev.perf_warn_fps or the active-body
## budget (rules.physics.max_active_bodies) is exceeded.
func set_perf(fps: float, active: int, peak: int) -> void:
	var budget := int(GameConfig.rule("physics.max_active_bodies"))
	var warn := fps < float(GameConfig.rule("dev.perf_warn_fps")) or peak > budget
	_perf.text = "%d FPS · aktif %d/%d · tepe %d" % [roundi(fps), active, budget, peak]
	_perf.add_theme_color_override("font_color", PERF_WARN_COLOR if warn else PERF_OK_COLOR)


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
	_won = true
	_win_stars = stars
	_show_banner("KAZANDIN!", _win_subtitle())


func _win_subtitle() -> String:
	var text := _stars_text(_win_stars)
	if _earned > 0:
		text += "\n+%d altın" % _earned
	return text + "\nR: tekrar"


func _stars_text(stars: int) -> String:
	var s := clampi(stars, 0, MAX_STARS)
	return STAR_FULL.repeat(s) + STAR_EMPTY.repeat(MAX_STARS - s)


func _on_currency_changed(currency: String, amount: int) -> void:
	if currency == GOLD:
		_set_gold(amount)


func _set_gold(amount: int) -> void:
	_gold.text = "%d ALTIN" % amount


## Progress paid gold for this level: first the win reward (stars + jackpot + world bonus; crystal
## gold was already paid during play), then possibly a late jackpot (core fell after the win).
## The win reward may arrive just before or just after level_completed.
func _on_level_rewarded(_level_id: String, breakdown: Dictionary) -> void:
	var jackpot := int(breakdown.get("jackpot", 0))
	if jackpot > 0:
		_jackpot.text = "JACKPOT!\n+%d altın" % jackpot
		_jackpot.visible = true
	_earned += int(breakdown.get("total", 0)) + int(breakdown.get("crystal", 0))
	if _won:
		_sub_banner.text = _win_subtitle()


func _on_level_failed() -> void:
	_show_banner("KAYBETTİN", "Gülle bitti · R: tekrar")


## The jackpot amount comes with EventBus.level_rewarded, which may fire before or after this.
func _on_core_dropped(_core: Node3D) -> void:
	if _jackpot.visible:
		return
	_jackpot.text = "JACKPOT!"
	_jackpot.visible = true


func _show_banner(title: String, subtitle: String) -> void:
	_banner.text = title
	_sub_banner.text = subtitle
	_banner.visible = true
	_sub_banner.visible = true
