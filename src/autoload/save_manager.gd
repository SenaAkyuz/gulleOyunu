extends Node
## Persistent save (docs/02 §8, Faz 2 Step 3): one JSON file in user:// (rules.save.file).
## - Versioned: "save_version". Older saves are upgraded step by step by _migrate_vN_to_vN1();
##   a save from a NEWER game version is never overwritten (read-only until the game is updated).
## - Atomic write: write <file>.tmp, re-read it to make sure it parses, keep the current good file
##   as rules.save.backup_file, then move the .tmp over the real file.
## - Corrupt / unreadable file: fall back to the backup, else start fresh (the broken file is kept
##   as <file>.corrupt for inspection). load_status tells what happened.
## Other autoloads (Economy, Progress, Inventory) own their sections of `data`, change them and
## call request_save(); writes are coalesced to at most one per frame.

const CURRENT_VERSION := 1
const TMP_SUFFIX := ".tmp"
const CORRUPT_SUFFIX := ".corrupt"
const JSON_INDENT := "\t"

enum LoadStatus { NEW, LOADED, MIGRATED, RECOVERED_BACKUP, RESET_CORRUPT, NEWER_VERSION }
const STATUS_NAMES := {
	LoadStatus.NEW: "yeni kayıt", LoadStatus.LOADED: "yüklendi", LoadStatus.MIGRATED: "yükseltildi",
	LoadStatus.RECOVERED_BACKUP: "yedekten kurtarıldı", LoadStatus.RESET_CORRUPT: "bozuktu, sıfırlandı",
	LoadStatus.NEWER_VERSION: "daha yeni sürümün kaydı (salt okunur)",
}

signal loaded(status: LoadStatus)

var data: Dictionary = {}
var load_status: LoadStatus = LoadStatus.NEW
## True when the file on disk came from a newer game version: never overwrite it.
var read_only: bool = false
## Overridable for tests (GUT points these at throw-away files).
var save_path: String = ""
var backup_path: String = ""

var _save_queued: bool = false


func _ready() -> void:
	if not GameConfig.is_valid():
		return
	if is_test_run():
		# Tests and simulations never touch the player's save (rules.save.test_file).
		save_path = str(GameConfig.rule("save.test_file"))
		backup_path = str(GameConfig.rule("save.test_backup_file"))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	else:
		save_path = str(GameConfig.rule("save.file"))
		backup_path = str(GameConfig.rule("save.backup_file"))
	load_game()


## True for test / tool runs: a command-line script (-s / --script: GUT, sim_cli, candidates_cli)
## or a GUT runner scene started from the editor. The real game never matches.
static func is_test_run() -> bool:
	var args := OS.get_cmdline_args()
	if args.has("-s") or args.has("--script"):
		return true
	for a in args:
		if a.contains("addons/gut") or a.contains("src/tools/"):
			return true
	return false


## Fresh save for a new player (values from game_data, nothing hard-coded).
func default_data() -> Dictionary:
	var settings: Dictionary = (GameConfig.rule("save.default_settings") as Dictionary).duplicate(true)
	settings["haptics"] = bool(GameConfig.rule("feel.haptics_default_on"))
	return {
		"save_version": CURRENT_VERSION,
		"gold": int(GameConfig.economy().get("currencies", {}).get("gold", {}).get("start_amount", 0)),
		"inventory": {},
		"levels": {},
		"unlocked_balls": [GameConfig.starting_ball_id()],
		"settings": settings,
		"flags": {},
	}


func load_game() -> LoadStatus:
	read_only = false
	var parsed: Variant = _read_json(save_path)
	if parsed == null and FileAccess.file_exists(save_path):
		push_warning("SaveManager: kayıt okunamadı, yedek deneniyor: " + save_path)
		DirAccess.copy_absolute(_abs(save_path), _abs(save_path + CORRUPT_SUFFIX))
		parsed = _read_json(backup_path)
		load_status = LoadStatus.RECOVERED_BACKUP if parsed != null else LoadStatus.RESET_CORRUPT
	elif parsed == null:
		load_status = LoadStatus.NEW
	else:
		load_status = LoadStatus.LOADED

	if parsed == null:
		data = default_data()
	else:
		var version := int((parsed as Dictionary).get("save_version", 0))
		if version > CURRENT_VERSION:
			push_warning("SaveManager: kayıt daha yeni bir sürümden (v%d > v%d); üzerine yazılmayacak" % [version, CURRENT_VERSION])
			read_only = true
			load_status = LoadStatus.NEWER_VERSION
			data = _fill_missing(parsed as Dictionary)
		else:
			if version < CURRENT_VERSION and load_status == LoadStatus.LOADED:
				load_status = LoadStatus.MIGRATED
			data = _fill_missing(migrate(parsed as Dictionary))
	data["gold"] = int(data.get("gold", 0))  # JSON numbers load as float
	print("SaveManager: %s (%s)" % [STATUS_NAMES[load_status], save_path])
	loaded.emit(load_status)
	if load_status in [LoadStatus.NEW, LoadStatus.MIGRATED, LoadStatus.RECOVERED_BACKUP, LoadStatus.RESET_CORRUPT]:
		save_game()
	return load_status


## Coalesced save: callers change `data` then call this; written once at the end of the frame.
func request_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	_flush.call_deferred(save_path)


## Deferred half of request_save(): skipped if cancelled or if the target file changed meanwhile
## (e.g. a test sandbox restored the real path), so a queued write never lands in the wrong file.
func _flush(path: String) -> void:
	if not _save_queued or path != save_path:
		_save_queued = false
		return
	save_game()


func cancel_pending_save() -> void:
	_save_queued = false


## Atomic write. Returns OK or an Error code; never overwrites a newer-version save.
func save_game() -> Error:
	_save_queued = false
	if read_only:
		return ERR_FILE_NO_PERMISSION
	data["save_version"] = CURRENT_VERSION
	var text := JSON.stringify(data, JSON_INDENT)
	var tmp := save_path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: yazılamadı %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	if _read_json(tmp) == null:
		push_error("SaveManager: geçici kayıt doğrulanamadı: " + tmp)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(save_path) and _read_json(save_path) != null:
		DirAccess.copy_absolute(_abs(save_path), _abs(backup_path))
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(_abs(save_path))
	var err := DirAccess.rename_absolute(_abs(tmp), _abs(save_path))
	if err != OK:
		push_error("SaveManager: kayıt taşınamadı (%s)" % error_string(err))
	return err


## Dev / settings "reset progress": fresh data, written immediately (backup keeps the old one).
func reset() -> void:
	read_only = false
	data = default_data()
	load_status = LoadStatus.NEW
	save_game()
	loaded.emit(load_status)


func status_name() -> String:
	return STATUS_NAMES[load_status]


## Upgrades an older save one version at a time (save_version missing = v0).
func migrate(old: Dictionary) -> Dictionary:
	var d := old.duplicate(true)
	var version := int(d.get("save_version", 0))
	while version < CURRENT_VERSION:
		var method := "_migrate_v%d_to_v%d" % [version, version + 1]
		if not has_method(method):
			push_error("SaveManager: %s yok; kayıt varsayılanlarla tamamlanıyor" % method)
			break
		d = call(method, d)
		version += 1
		d["save_version"] = version
	return d


## v0 = development saves written before versioning: same fields, no "save_version";
## "gold" may have been stored as a float.
func _migrate_v0_to_v1(d: Dictionary) -> Dictionary:
	if d.has("gold"):
		d["gold"] = int(d["gold"])
	return d


## Adds any top-level / settings key a save lacks (new fields get their defaults).
func _fill_missing(d: Dictionary) -> Dictionary:
	var defaults := default_data()
	for key: String in defaults:
		if not d.has(key):
			d[key] = defaults[key]
	if d["settings"] is Dictionary:
		for key: String in (defaults["settings"] as Dictionary):
			if not (d["settings"] as Dictionary).has(key):
				d["settings"][key] = defaults["settings"][key]
	return d


## Parsed Dictionary or null (missing, unreadable, not JSON, not an object).
func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	return json.data


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
