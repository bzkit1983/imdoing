extends RefCounted
## Steam PlatformServices backend (M3 → H1).
## Local disk remains source of truth; Cloud／UserStats sync when Steam is live.
## Formal App ID still required for shipping — see docs/alpha/steam-productization.md.

const DesktopPlatform = preload("res://scripts/platform/desktop_platform.gd")
const SAVE_CLOUD_NAME := "save.json"
const GUEST_CLOUD_NAME := "guest_slots.json"

var _disk = DesktopPlatform.new()


func write_save(text: String) -> String:
	var err: String = _disk.write_save(text)
	if err != "":
		return err
	_cloud_write(SAVE_CLOUD_NAME, text)
	return ""


func read_save() -> String:
	var local := _disk.read_save()
	if local != "":
		return local
	## Cold start／reinstall: try Cloud if local missing.
	var cloud := _cloud_read(SAVE_CLOUD_NAME)
	if cloud != "":
		_disk.write_save(cloud)
		return cloud
	return ""


func has_save() -> bool:
	if _disk.has_save():
		return true
	return _cloud_exists(SAVE_CLOUD_NAME)


func delete_save() -> void:
	_disk.delete_save()
	_cloud_delete(SAVE_CLOUD_NAME)


func write_guest_slots(text: String) -> String:
	var err: String = _disk.write_guest_slots(text)
	if err != "":
		return err
	_cloud_write(GUEST_CLOUD_NAME, text)
	return ""


func read_guest_slots() -> String:
	var local := _disk.read_guest_slots()
	if local != "":
		return local
	var cloud := _cloud_read(GUEST_CLOUD_NAME)
	if cloud != "":
		_disk.write_guest_slots(cloud)
		return cloud
	return ""


func has_guest_slots() -> bool:
	if _disk.has_guest_slots():
		return true
	return _cloud_exists(GUEST_CLOUD_NAME)


func delete_guest_slots() -> void:
	_disk.delete_guest_slots()
	_cloud_delete(GUEST_CLOUD_NAME)


func checkpoint() -> void:
	_disk.checkpoint()
	## Flush Cloud after local checkpoint (suspend／pause).
	if _disk.has_save():
		_cloud_write(SAVE_CLOUD_NAME, _disk.read_save())
	if _disk.has_guest_slots():
		_cloud_write(GUEST_CLOUD_NAME, _disk.read_guest_slots())


func unlock_achievement(id: String) -> void:
	var steam = _steam()
	if steam == null:
		print("[steam_platform] achievement unlock (no Steam): ", id)
		return
	if not steam.has_method("setAchievement") or not steam.has_method("storeStats"):
		print("[steam_platform] achievement unlock (API missing): ", id)
		return
	## GodotSteam: setAchievement(name) → storeStats()
	var ok: bool = bool(steam.call("setAchievement", id))
	if ok:
		steam.call("storeStats")
	else:
		## Spacewar 480／未在 Partner 登記的 id 常失敗；仍留 log 方便 QA。
		print("[steam_platform] setAchievement failed: ", id)


func get_ui_profile() -> String:
	return _disk.get_ui_profile()


func _steam():
	if not Engine.has_singleton("Steam"):
		return null
	return Engine.get_singleton("Steam")


func _cloud_write(file_name: String, text: String) -> void:
	var steam = _steam()
	if steam == null or not steam.has_method("fileWrite"):
		return
	var bytes := text.to_utf8_buffer()
	## GodotSteam fileWrite(file_name, data: PackedByteArray) → bool
	var ok: bool = bool(steam.call("fileWrite", file_name, bytes))
	if not ok:
		print("[steam_platform] Cloud fileWrite failed: ", file_name)


func _cloud_read(file_name: String) -> String:
	var steam = _steam()
	if steam == null or not steam.has_method("fileRead"):
		return ""
	if not _cloud_exists(file_name):
		return ""
	var data = steam.call("fileRead", file_name)
	if typeof(data) != TYPE_PACKED_BYTE_ARRAY:
		return ""
	var bytes: PackedByteArray = data
	if bytes.is_empty():
		return ""
	return bytes.get_string_from_utf8()


func _cloud_exists(file_name: String) -> bool:
	var steam = _steam()
	if steam == null or not steam.has_method("fileExists"):
		return false
	return bool(steam.call("fileExists", file_name))


func _cloud_delete(file_name: String) -> void:
	var steam = _steam()
	if steam == null or not steam.has_method("fileDelete"):
		return
	steam.call("fileDelete", file_name)
