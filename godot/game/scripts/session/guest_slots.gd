extends RefCounted
## Persistent local guest character slots (max 3). Character-only; no shop fields.

const CharacterSheet = preload("res://scripts/session/character_sheet.gd")

const MAX_SLOTS := 3
const VERSION := 1

## Array of size MAX_SLOTS; each entry is {} (empty) or a character dict.
var slots: Array = [{}, {}, {}]


static func create() -> RefCounted:
	var store = load("res://scripts/session/guest_slots.gd").new()
	store.load_from_disk()
	return store


func load_from_disk() -> void:
	slots = [{}, {}, {}]
	if not PlatformServices.has_guest_slots():
		return
	var text := PlatformServices.read_guest_slots()
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var raw = data.get("slots", [])
	if not (raw is Array):
		return
	for i in mini(MAX_SLOTS, raw.size()):
		var row = raw[i]
		if row is Dictionary and not (row as Dictionary).is_empty():
			slots[i] = (row as Dictionary).duplicate(true)
		else:
			slots[i] = {}


func save_to_disk() -> String:
	var out_slots: Array = []
	for i in MAX_SLOTS:
		out_slots.append(slots[i] if slots[i] is Dictionary else {})
	var payload := {"version": VERSION, "slots": out_slots}
	return PlatformServices.write_guest_slots(JSON.stringify(payload, "\t"))


func clear_all() -> void:
	slots = [{}, {}, {}]
	PlatformServices.delete_guest_slots()


func is_empty(index: int) -> bool:
	if index < 0 or index >= MAX_SLOTS:
		return true
	var row = slots[index]
	return not (row is Dictionary) or (row as Dictionary).is_empty()


func get_sheet(index: int):
	if is_empty(index):
		return null
	return CharacterSheet.from_dict(slots[index] as Dictionary)


func set_sheet(index: int, sheet) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	if sheet == null:
		slots[index] = {}
		return
	slots[index] = sheet.to_dict()


func clone_host_into(index: int, host_state) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	var sheet = CharacterSheet.from_game_state(host_state)
	sheet.display_name = "訪客%d" % (index + 1)
	slots[index] = sheet.to_dict()


func create_blank_at(index: int) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	var sheet = CharacterSheet.blank()
	sheet.display_name = "訪客%d" % (index + 1)
	slots[index] = sheet.to_dict()


func label_for(index: int) -> String:
	if is_empty(index):
		return "（空）"
	var sheet = get_sheet(index)
	if sheet == null:
		return "（空）"
	return sheet.summary_line()
