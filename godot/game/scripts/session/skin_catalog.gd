extends RefCounted
## Player appearance skins for prep Look page + runtime spawn.
## unlocked_skins empty ⇒ all catalog entries are unlocked (BETA).

const DEFAULT_SKIN := "player"

const ENTRIES: Array[Dictionary] = [
	{"id": "player", "name_key": "skin.player"},
	{"id": "player_alt1", "name_key": "skin.player_alt1"},
	{"id": "player_alt2", "name_key": "skin.player_alt2"},
	{"id": "player_alt3", "name_key": "skin.player_alt3"},
]


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for e in ENTRIES:
		out.append(String(e.get("id", "")))
	return out


static func entry(skin_id: String) -> Dictionary:
	var id := String(skin_id)
	for e in ENTRIES:
		if String(e.get("id", "")) == id:
			return e
	return {}


static func display_name(skin_id: String) -> String:
	var e := entry(skin_id)
	if e.is_empty():
		return skin_id if skin_id != "" else DEFAULT_SKIN
	var key := String(e.get("name_key", ""))
	if key != "" and Loc != null and Loc.has_method("t"):
		return Loc.t(key)
	return id_fallback_label(skin_id)


static func id_fallback_label(skin_id: String) -> String:
	match String(skin_id):
		"player_alt1":
			return Loc.t("skin.player_alt1")
		"player_alt2":
			return Loc.t("skin.player_alt2")
		"player_alt3":
			return Loc.t("skin.player_alt3")
		"player", "":
			return Loc.t("skin.player")
		_:
			return String(skin_id)


static func normalize(skin_id: String) -> String:
	var id := String(skin_id).strip_edges()
	if id == "" or entry(id).is_empty():
		return DEFAULT_SKIN
	## Prefer baked anim pack; fall back if sprites missing.
	var Vox = load("res://scripts/voxel_sprite.gd")
	if Vox != null and Vox.has_method("has_anim") and not bool(Vox.has_anim(id, "idle")):
		return DEFAULT_SKIN
	return id


static func is_unlocked(skin_id: String, unlocked_skins) -> bool:
	var id := normalize(skin_id)
	if unlocked_skins == null:
		return true
	if not (unlocked_skins is Array):
		return true
	var arr: Array = unlocked_skins
	## Empty list = all unlocked (BETA default).
	if arr.is_empty():
		return true
	for raw in arr:
		if String(raw) == id:
			return true
	return false


static func unlocked_entries(unlocked_skins) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in ENTRIES:
		var id := String(e.get("id", ""))
		if is_unlocked(id, unlocked_skins):
			out.append(e)
	if out.is_empty():
		out.append(ENTRIES[0])
	return out


static func parse_unlocked(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw:
			var id := String(v).strip_edges()
			if id != "" and not entry(id).is_empty() and id not in out:
				out.append(id)
	return out
