class_name JsonPatcher
extends RefCounted
## Replaces one number inside a JSON text without touching anything else (formatting, key order,
## "_doc" comments stay as written). Used by the Dev Panel's "JSON'a kaydet".
## A path is a list of segments: a String = object key, a Dictionary {"id": x} = the array element
## whose "id" equals x. Example: ["balls", {"id": "heavy"}, "launch_speed"].

const WHITESPACE := " \t\r\n"


## Returns the patched text, or "" if the path was not found or the result would not parse.
static func set_number(text: String, path: Array, value: float, decimals: int) -> String:
	var start := _skip_ws(text, 0)
	for segment: Variant in path:
		if segment is String:
			start = _find_member(text, start, segment)
		else:
			start = _find_element(text, start, segment as Dictionary)
		if start < 0:
			return ""
	var end := _value_end(text, start)
	var patched := text.substr(0, start) + format_number(value, decimals) + text.substr(end)
	if JSON.parse_string(patched) == null:
		return ""
	return patched


## Integers stay integers ("120"), others use the slider step's decimals ("9.8").
static func format_number(value: float, decimals: int) -> String:
	if decimals <= 0:
		return str(roundi(value))
	return String.num(value, decimals)


## Number of decimals needed to show a slider step (0.1 -> 1, 0.001 -> 3, 5 -> 0).
static func decimals_for(step: float) -> int:
	var d := 0
	var s := step
	while not is_equal_approx(s, roundf(s)) and d < 6:
		s *= 10.0
		d += 1
	return d


static func _skip_ws(text: String, i: int) -> int:
	while i < text.length() and WHITESPACE.contains(text[i]):
		i += 1
	return i


## `obj` points at "{". Returns the start index of `key`'s value, or -1.
static func _find_member(text: String, obj: int, key: String) -> int:
	if obj >= text.length() or text[obj] != "{":
		return -1
	var i := _skip_ws(text, obj + 1)
	while i < text.length() and text[i] != "}":
		var key_end := _value_end(text, i)
		var name := text.substr(i + 1, key_end - i - 2)
		i = _skip_ws(text, key_end)
		if text[i] != ":":
			return -1
		var value_start := _skip_ws(text, i + 1)
		if name == key:
			return value_start
		i = _skip_ws(text, _value_end(text, value_start))
		if i < text.length() and text[i] == ",":
			i = _skip_ws(text, i + 1)
	return -1


## `arr` points at "[". Returns the start of the object element whose fields match `match_fields`.
static func _find_element(text: String, arr: int, match_fields: Dictionary) -> int:
	if arr >= text.length() or text[arr] != "[":
		return -1
	var i := _skip_ws(text, arr + 1)
	while i < text.length() and text[i] != "]":
		var end := _value_end(text, i)
		var element: Variant = JSON.parse_string(text.substr(i, end - i))
		if element is Dictionary:
			var ok := true
			for k: Variant in match_fields:
				if (element as Dictionary).get(k) != match_fields[k]:
					ok = false
			if ok:
				return i
		i = _skip_ws(text, end)
		if i < text.length() and text[i] == ",":
			i = _skip_ws(text, i + 1)
	return -1


## Index just after the JSON value that starts at `i` (string, object, array or literal).
static func _value_end(text: String, i: int) -> int:
	var c := text[i]
	if c == "\"":
		i += 1
		while i < text.length() and text[i] != "\"":
			i += 2 if text[i] == "\\" else 1
		return i + 1
	if c == "{" or c == "[":
		var depth := 0
		while i < text.length():
			var ch := text[i]
			if ch == "\"":
				i = _value_end(text, i)
				continue
			if ch == "{" or ch == "[":
				depth += 1
			elif ch == "}" or ch == "]":
				depth -= 1
				if depth == 0:
					return i + 1
			i += 1
		return i
	while i < text.length() and not (",}]" + WHITESPACE).contains(text[i]):
		i += 1
	return i
