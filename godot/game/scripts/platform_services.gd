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

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "ui"
const SETTINGS_VIRTUAL_STICK := "virtual_stick"
const SETTINGS_CAMERA_VIEW := "camera_view"

const CAMERA_VIEW_NORMAL := "normal"
const CAMERA_VIEW_FAR := "far"
const CAMERA_VIEW_OVERVIEW := "overview"
const CAMERA_VIEW_CYCLE: Array[String] = [
	CAMERA_VIEW_NORMAL,
	CAMERA_VIEW_FAR,
	CAMERA_VIEW_OVERVIEW,
]

signal suspended
signal resumed
signal pause_menu_requested
## Fired when the player toggles on-screen stick visibility (prep System tools).
signal virtual_stick_changed(enabled: bool)
## Fired when shop camera framing mode changes (pause / View button).
signal camera_view_changed(mode: String)

var _backend = DesktopPlatform.new()
## Player preference; only applies when the platform profile is touch (Web / mobile).
## Default off (tester/PM): player opts in via Prep System tools or Pause.
var _virtual_stick: bool = false
## Shop camera framing: normal | far | overview. Persists across days.
var _camera_view: String = CAMERA_VIEW_NORMAL


func _ready() -> void:
	# Pause notifications only reach this node when process mode allows it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_ui_settings()


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


## On-screen TouchPad visibility. Live rule lives on InputMode (pref + active device).
func show_touch_pad() -> bool:
	var im := get_node_or_null("/root/InputMode")
	if im and im.has_method("show_vj"):
		return bool(im.call("show_vj"))
	return wants_touch_pad() and _virtual_stick


func is_virtual_stick_enabled() -> bool:
	return _virtual_stick


func set_virtual_stick_enabled(on: bool) -> void:
	var next := bool(on)
	if next == _virtual_stick:
		return
	_virtual_stick = next
	_save_ui_settings()
	virtual_stick_changed.emit(_virtual_stick)


func toggle_virtual_stick() -> bool:
	set_virtual_stick_enabled(not _virtual_stick)
	return _virtual_stick


func get_camera_view() -> String:
	return _camera_view


func set_camera_view(mode: String) -> void:
	var next := _normalize_camera_view(mode)
	if next == _camera_view:
		return
	_camera_view = next
	_save_ui_settings()
	camera_view_changed.emit(_camera_view)


func cycle_camera_view() -> String:
	var i := CAMERA_VIEW_CYCLE.find(_camera_view)
	if i < 0:
		i = 0
	var next := CAMERA_VIEW_CYCLE[(i + 1) % CAMERA_VIEW_CYCLE.size()]
	set_camera_view(next)
	return _camera_view


func wants_focus_ui() -> bool:
	var profile := get_ui_profile()
	return profile == "gamepad" or profile == "tv"


func _normalize_camera_view(mode: String) -> String:
	var m := String(mode).strip_edges()
	if m in CAMERA_VIEW_CYCLE:
		return m
	return CAMERA_VIEW_NORMAL


func _load_ui_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	_virtual_stick = bool(cf.get_value(SETTINGS_SECTION, SETTINGS_VIRTUAL_STICK, false))
	_camera_view = _normalize_camera_view(
		String(cf.get_value(SETTINGS_SECTION, SETTINGS_CAMERA_VIEW, CAMERA_VIEW_NORMAL))
	)


func _save_ui_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value(SETTINGS_SECTION, SETTINGS_VIRTUAL_STICK, _virtual_stick)
	cf.set_value(SETTINGS_SECTION, SETTINGS_CAMERA_VIEW, _camera_view)
	cf.save(SETTINGS_PATH)


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
