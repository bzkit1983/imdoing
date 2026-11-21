extends RefCounted
## SfxBus / BgmBus / PlatformServices toggles shared by prep settings and pause settings.

const BgmBusScript = preload("res://scripts/bgm_bus.gd")


static func _bgm() -> Node:
	return BgmBusScript.bus()


static func toggle_sfx() -> void:
	if SfxBus.is_muted():
		SfxBus.set_muted(false)
		SfxBus.play("sfx_ui_confirm")
	else:
		SfxBus.play("sfx_ui_confirm")
		SfxBus.set_muted(true)


static func nudge_sfx_volume(steps: int) -> void:
	if steps == 0:
		SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)
		return
	SfxBus.nudge_volume(steps)
	SfxBus.play("sfx_ui_move", 1.0, NAN, true)


static func pause_preview_sfx_volume() -> void:
	SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)


static func prep_toggle_sfx() -> String:
	toggle_sfx()
	return Loc.t("pause.sfx_on" if not SfxBus.is_muted() else "pause.sfx_off")


static func prep_nudge_sfx_volume(steps: int) -> String:
	nudge_sfx_volume(steps)
	return Loc.t("pause.sfx_volume", [SfxBus.volume_percent()])


static func pause_sfx_mute_label() -> String:
	return Loc.t("pause.sfx_off") if SfxBus.is_muted() else Loc.t("pause.sfx_on")


static func pause_sfx_volume_label() -> String:
	return Loc.t("pause.sfx_volume", [SfxBus.volume_percent()])


static func prep_toggle_bgm() -> String:
	var bgm: Node = _bgm()
	if bgm == null:
		return ""
	var muted: bool = bgm.toggle_muted()
	SfxBus.play("sfx_ui_confirm")
	return Loc.t("prep.sys.bgm_off" if muted else "prep.sys.bgm_on")


static func pause_toggle_bgm() -> void:
	var bgm: Node = _bgm()
	if bgm == null:
		return
	if bgm.is_muted():
		bgm.set_muted(false)
		SfxBus.play("sfx_ui_confirm")
	else:
		SfxBus.play("sfx_ui_confirm")
		bgm.set_muted(true)


static func nudge_bgm_volume(steps: int) -> void:
	var bgm: Node = _bgm()
	if bgm == null:
		return
	if steps == 0:
		bgm.preview_volume()
		SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)
		return
	bgm.nudge_volume(steps)
	bgm.preview_volume()
	SfxBus.play("sfx_ui_move", 1.0, NAN, true)


static func prep_nudge_bgm_volume(steps: int) -> String:
	var bgm: Node = _bgm()
	if bgm == null:
		return ""
	nudge_bgm_volume(steps)
	return Loc.t("prep.sys.bgm_volume", [bgm.volume_percent()])


static func pause_preview_bgm_volume() -> void:
	var bgm: Node = _bgm()
	if bgm:
		bgm.preview_volume()
	SfxBus.play("sfx_ui_confirm", 1.0, NAN, true)


static func pause_bgm_mute_label() -> String:
	var bgm: Node = _bgm()
	if bgm == null:
		return ""
	return Loc.t("pause.bgm_off") if bgm.is_muted() else Loc.t("pause.bgm_on")


static func pause_bgm_volume_label() -> String:
	var bgm: Node = _bgm()
	if bgm == null:
		return ""
	return Loc.t("pause.bgm_volume", [bgm.volume_percent()])


static func prep_toggle_virtual_stick() -> String:
	var on := PlatformServices.toggle_virtual_stick()
	SfxBus.play("sfx_ui_confirm")
	return Loc.t("prep.sys.virtual_stick_on" if on else "prep.sys.virtual_stick_off")


static func pause_toggle_virtual_stick() -> void:
	PlatformServices.toggle_virtual_stick()
	SfxBus.play("sfx_ui_confirm")


static func camera_view_msg() -> String:
	match PlatformServices.get_camera_view():
		PlatformServices.CAMERA_VIEW_FAR:
			return Loc.t("pause.camera_far")
		PlatformServices.CAMERA_VIEW_OVERVIEW:
			return Loc.t("pause.camera_overview")
		_:
			return Loc.t("pause.camera_normal")


static func prep_cycle_camera() -> String:
	PlatformServices.cycle_camera_view()
	SfxBus.play("sfx_ui_confirm")
	return camera_view_msg()


static func pause_cycle_camera() -> void:
	PlatformServices.cycle_camera_view()
	SfxBus.play("sfx_ui_confirm")


static func prep_toggle_dev_hud() -> String:
	var on := PlatformServices.toggle_show_dev_hud()
	SfxBus.play("sfx_ui_confirm")
	return Loc.t("prep.sys.dev_hud_on" if on else "prep.sys.dev_hud_off")


static func prep_set_locale(code: String) -> String:
	PlatformServices.set_locale(code)
	SfxBus.play("sfx_ui_confirm")
	var lang_name := Loc.t("locale.name.%s" % Loc.get_locale())
	return Loc.t("prep.locale.changed", [lang_name])


static func pause_set_locale(code: String) -> void:
	PlatformServices.set_locale(code)
	SfxBus.play("sfx_ui_confirm")