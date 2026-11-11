extends RefCounted
## Steam PlatformServices backend (M3).
## Local disk I/O matches Desktop; Cloud／UserStats／Steam Input fill in
## after GodotSteam + real App ID — see docs/alpha/godotsteam-setup.md.

const DesktopPlatform = preload("res://scripts/platform/desktop_platform.gd")

var _disk = DesktopPlatform.new()


func write_save(text: String) -> String:
	## Later: Steam Cloud sync after local write.
	return _disk.write_save(text)


func read_save() -> String:
	return _disk.read_save()


func has_save() -> bool:
	return _disk.has_save()


func delete_save() -> void:
	_disk.delete_save()


func write_guest_slots(text: String) -> String:
	return _disk.write_guest_slots(text)


func read_guest_slots() -> String:
	return _disk.read_guest_slots()


func has_guest_slots() -> bool:
	return _disk.has_guest_slots()


func delete_guest_slots() -> void:
	_disk.delete_guest_slots()


func checkpoint() -> void:
	_disk.checkpoint()


func unlock_achievement(id: String) -> void:
	## No-op until Steam UserStats wired; still log for QA.
	print("[steam_platform] achievement unlock (stub): ", id)


func get_ui_profile() -> String:
	return _disk.get_ui_profile()
