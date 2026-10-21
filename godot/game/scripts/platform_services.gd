extends Node
## Autoload facade for platform I/O. Gameplay talks only to this node.
## Desktop stub now; Steam / Switch / Xbox backends plug in behind the same API.
##
## Minimal surface (tech-review):
## - save / load / delete
## - checkpoint before suspend
## - achievement_unlock (log / no-op on hosts without achievements)
## - get_ui_profile: "touch" | "gamepad" | "tv"

const DesktopPlatform = preload("res://scripts/platform/desktop_platform.gd")

signal suspended
signal resumed
signal pause_menu_requested

var _backend = DesktopPlatform.new()


func _ready() -> void:
	# Pause notifications only reach this node when process mode allows it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func write_save(text: String) -> String:
	return _backend.write_save(text)


func read_save() -> String:
	return _backend.read_save()


func has_save() -> bool:
	return _backend.has_save()


func delete_save() -> void:
	_backend.delete_save()


## Call before app suspend / pause menu; Desktop writes are already sync.
func checkpoint() -> void:
	_backend.checkpoint()


func unlock_achievement(id: String) -> void:
	if id.strip_edges() == "":
		return
	_backend.unlock_achievement(id)


func get_ui_profile() -> String:
	return _backend.get_ui_profile()


func wants_touch_pad() -> bool:
	return get_ui_profile() == "touch"


func wants_focus_ui() -> bool:
	var profile := get_ui_profile()
	return profile == "gamepad" or profile == "tv"


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# Flush platform I/O, then ask the game to show the pause menu.
			checkpoint()
			suspended.emit()
			pause_menu_requested.emit()
		NOTIFICATION_APPLICATION_RESUMED:
			resumed.emit()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Desktop window switch: checkpoint only; do not force the pause UI.
			checkpoint()
		NOTIFICATION_WM_CLOSE_REQUEST:
			checkpoint()
