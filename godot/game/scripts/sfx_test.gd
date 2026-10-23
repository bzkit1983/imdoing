extends CanvasLayer
## Standalone Alpha SFX sample page. Run scene `res://scenes/sfx_test.tscn`.
## Lists every catalog ID; J / click plays. Esc / ; quits to main demo if embedded,
## or quits the tree when run alone.

const SfxCatalog = preload("res://scripts/sfx_catalog.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var _list: ItemList
var _title: Label
var _info: Label
var _ids: PackedStringArray = PackedStringArray()
var _index: int = 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_fill()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("1c241f")
	root.add_child(bg)
	_title = Label.new()
	_title.text = Loc.t("prep.sfx.title")
	_title.position = Vector2(24, 20)
	_title.size = Vector2(1232, 48)
	UiFont.apply_label(_title, 40)
	_title.add_theme_color_override("font_color", Color("f4d35e"))
	root.add_child(_title)
	_info = Label.new()
	_info.text = Loc.t("prep.sfx.info")
	_info.position = Vector2(24, 72)
	_info.size = Vector2(1232, 56)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFont.apply_label(_info, 22)
	_info.add_theme_color_override("font_color", Color("f4f1ea"))
	root.add_child(_info)
	_list = ItemList.new()
	_list.position = Vector2(24, 140)
	_list.size = Vector2(1232, 520)
	_list.allow_reselect = true
	_list.add_theme_font_override("font", UiFont.font())
	_list.add_theme_font_size_override("font_size", UiFont.px(26))
	_list.add_theme_color_override("font_color", Color("f4f1ea"))
	_list.add_theme_color_override("font_selected_color", Color("1c241f"))
	_list.item_activated.connect(_on_activated)
	_list.item_selected.connect(func(i: int) -> void: _index = i)
	root.add_child(_list)
	var hint := Label.new()
	hint.text = "W／S 選擇　　J 播放　　Esc／; 離開"
	hint.position = Vector2(24, 670)
	hint.size = Vector2(1232, 32)
	UiFont.apply_label(hint, 20)
	hint.add_theme_color_override("font_color", Color("c8c2b4"))
	root.add_child(hint)


func _fill() -> void:
	_list.clear()
	_ids.clear()
	for pri in ["P0", "P1", "P2"]:
		_list.add_item("—— %s ——" % pri)
		_list.set_item_disabled(_list.item_count - 1, true)
		_ids.append("")
		for e in SfxCatalog.by_priority(pri):
			var sid := String(e["id"])
			var group := String(e.get("group", ""))
			var trigger := String(e.get("trigger", ""))
			if trigger == "":
				_list.add_item("[%s] %s　▶" % [group, sid])
			else:
				_list.add_item("[%s] %s　▶　%s" % [group, sid, trigger])
			_ids.append(sid)
	_index = 1 if _ids.size() > 1 else 0
	if _list.item_count > _index:
		_list.select(_index)
		_list.ensure_current_is_visible()


func _on_activated(index: int) -> void:
	_play_at(index)


func _play_at(index: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	var sid := _ids[index]
	if sid == "":
		return
	SfxBus.play(sid)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(Controls.CANCEL) or event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(Controls.MOVE_UP):
		_nudge(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.MOVE_DOWN):
		_nudge(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.INTERACT):
		_play_at(_index)
		get_viewport().set_input_as_handled()


func _nudge(dir: int) -> void:
	if _ids.is_empty():
		return
	var i := _index
	for _k in _ids.size():
		i = posmod(i + dir, _ids.size())
		if _ids[i] != "":
			break
	_index = i
	_list.select(_index)
	_list.ensure_current_is_visible()
	SfxBus.play("sfx_ui_move")


func _leave() -> void:
	SfxBus.play("sfx_ui_cancel")
	## If this is the main scene, quit; otherwise free overlay.
	if get_tree().current_scene == self:
		get_tree().quit()
	else:
		queue_free()
