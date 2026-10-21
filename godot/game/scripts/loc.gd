extends Node
## Runtime string table for i18n. Source: res://locale/strings.csv
## Usage: Loc.t("pause.title")  or  Loc.t("hud.revenue", [rev, stolen])
## Default locale follows project fallback (zh_TW). Steam / EN later: Loc.set_locale("en").

const TABLE_PATH := "res://locale/strings.csv"
const DEFAULT_LOCALE := "zh_TW"

signal locale_changed(code: String)

var _locale: String = DEFAULT_LOCALE
var _tables: Dictionary = {} ## locale -> Dictionary[String, String]
var _locales: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()
	set_locale(DEFAULT_LOCALE)


func reload() -> void:
	_tables.clear()
	_locales = PackedStringArray()
	if not FileAccess.file_exists(TABLE_PATH):
		push_warning("Loc: missing %s" % TABLE_PATH)
		return
	var f := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if f == null:
		push_warning("Loc: cannot open %s" % TABLE_PATH)
		return
	var header := _parse_csv_line(f.get_line())
	if header.is_empty() or header[0] != "key":
		push_warning("Loc: CSV must start with key,<locale>,...")
		return
	for i in range(1, header.size()):
		var loc := String(header[i]).strip_edges()
		if loc == "":
			continue
		_locales.append(loc)
		_tables[loc] = {}
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var cols := _parse_csv_line(line)
		if cols.is_empty():
			continue
		var key := String(cols[0]).strip_edges()
		if key == "":
			continue
		for i in range(1, mini(cols.size(), header.size())):
			var loc := String(header[i]).strip_edges()
			if loc == "" or not _tables.has(loc):
				continue
			var cell := String(cols[i])
			(_tables[loc] as Dictionary)[key] = cell.replace("\\n", "\n")


func set_locale(code: String) -> void:
	if code == "" or not _tables.has(code):
		code = DEFAULT_LOCALE
	_locale = code
	TranslationServer.set_locale(code)
	locale_changed.emit(code)


func get_locale() -> String:
	return _locale


func locales() -> PackedStringArray:
	return _locales


func has_key(key: String) -> bool:
	var table: Dictionary = _tables.get(_locale, {})
	if table.has(key):
		return true
	var fb: Dictionary = _tables.get(DEFAULT_LOCALE, {})
	return fb.has(key)


## Lookup key; optional printf-style args applied to the translated template.
func t(key: String, args: Array = []) -> String:
	var text := _lookup(key)
	if args.is_empty():
		return text
	return text % args


func _lookup(key: String) -> String:
	var table: Dictionary = _tables.get(_locale, {})
	if table.has(key):
		return String(table[key])
	var fb: Dictionary = _tables.get(DEFAULT_LOCALE, {})
	if fb.has(key):
		return String(fb[key])
	push_warning("Loc: missing key '%s'" % key)
	return key


## Minimal CSV line parser (supports double-quoted fields with commas / "").
func _parse_csv_line(line: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur := ""
	var in_q := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if in_q:
			if ch == "\"":
				if i + 1 < line.length() and line[i + 1] == "\"":
					cur += "\""
					i += 2
					continue
				in_q = false
				i += 1
				continue
			cur += ch
			i += 1
			continue
		if ch == "\"":
			in_q = true
			i += 1
			continue
		if ch == ",":
			out.append(cur)
			cur = ""
			i += 1
			continue
		cur += ch
		i += 1
	out.append(cur)
	return out
