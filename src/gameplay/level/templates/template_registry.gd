class_name TemplateRegistry
extends RefCounted
## Template id -> script (docs/03 §4). A template lives in res://src/gameplay/level/templates/<id>.gd
## and extends TowerTemplate. Tests may register extra templates with register().

const DIR := "res://src/gameplay/level/templates/"

static var _extra: Dictionary = {}  # id -> Script


static func register(template_id: String, script: Script) -> void:
	_extra[template_id] = script


static func unregister(template_id: String) -> void:
	_extra.erase(template_id)


static func has(template_id: String) -> bool:
	return _extra.has(template_id) or ResourceLoader.exists(_path(template_id))


## New template instance, or null if the template is not written yet.
static func create(template_id: String) -> TowerTemplate:
	var script: Script = _extra.get(template_id)
	if script == null and ResourceLoader.exists(_path(template_id)):
		script = load(_path(template_id))
	if script == null:
		return null
	return script.new() as TowerTemplate


static func _path(template_id: String) -> String:
	return DIR + template_id + ".gd"
