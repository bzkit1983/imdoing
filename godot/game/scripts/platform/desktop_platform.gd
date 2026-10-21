extends RefCounted
## Desktop / Web file I/O for PlatformServices. Writes `user://save.json`.

const SAVE_PATH := "user://save.json"
const SAVE_FILE := "save.json"


func write_save(text: String) -> String:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return "無法寫入存檔（錯誤 %d）" % FileAccess.get_open_error()
	f.store_string(text)
	return ""


func read_save() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	return FileAccess.get_file_as_string(SAVE_PATH)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove(SAVE_FILE)


## Sync writes already flush; nothing pending on Desktop.
func checkpoint() -> void:
	pass


func unlock_achievement(id: String) -> void:
	print("[DesktopPlatform] achievement unlock (stub): ", id)


## Desktop keyboard/gamepad: hide on-screen TouchPad, prefer focus UI.
## Web / mobile keep touch chrome for the marketing playable.
func get_ui_profile() -> String:
	if OS.has_feature("web") or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return "touch"
	return "gamepad"
