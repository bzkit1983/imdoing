extends CanvasLayer
## Paged tutorial explain window (next / prev).
## Does NOT use get_tree().paused — that raced with day-start and could leave the tree frozen.
## Host freezes sim／input via TutorialDirector.is_modal_open().

const UiFont = preload("res://scripts/ui_font.gd")

signal finished
signal cancelled

var _pages: Array = []
var _index: int = 0
var _review: bool = false
var _open_queued: bool = false

@onready var _shade: ColorRect = %Shade
@onready var _card: PanelContainer = %Card
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _image: TextureRect = %Image
@onready var _page_lab: Label = %PageLabel
@onready var _prev_btn: Button = %PrevBtn
@onready var _next_btn: Button = %NextBtn


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.10, 0.96)
	sb.border_color = Color(0.96, 0.83, 0.37, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	_card.add_theme_stylebox_override("panel", sb)
	UiFont.apply_label(_title, 32)
	_title.add_theme_color_override("font_color", Color(0.96, 0.83, 0.37, 1))
	UiFont.apply_label(_body, 22)
	_body.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93, 1))
	UiFont.apply_label(_page_lab, 18)
	_page_lab.add_theme_color_override("font_color", Color(0.78, 0.80, 0.76, 1))
	UiFont.apply_button(_prev_btn, 20)
	UiFont.apply_button(_next_btn, 20)
	_prev_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.focus_mode = Control.FOCUS_NONE
	_prev_btn.pressed.connect(_on_prev)
	_next_btn.pressed.connect(_on_next)
	## Ensure shade／card eat mouse so prep／world do not receive clicks underneath.
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.mouse_filter = Control.MOUSE_FILTER_STOP


func is_open() -> bool:
	return visible


## pages: Array of { title_key, body_key, image_path? }
func open_pages(pages: Array, review: bool = false) -> void:
	_pages = pages.duplicate()
	_index = 0
	_review = review
	if _pages.is_empty():
		_pages = [{
			"title_key": "tut.modal.empty_title",
			"body_key": "tut.modal.empty_body",
			"image_path": "",
		}]
	if not is_node_ready():
		_open_queued = true
		if not ready.is_connected(_flush_queued_open):
			ready.connect(_flush_queued_open, CONNECT_ONE_SHOT)
		return
	_apply_open()


func _flush_queued_open() -> void:
	if not _open_queued:
		return
	_open_queued = false
	_apply_open()


func _apply_open() -> void:
	## Never touch get_tree().paused — release is easy to miss and freezes the day.
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
	visible = true
	_paint()


func close_modal(emit_cancel: bool = false) -> void:
	_open_queued = false
	visible = false
	## Safety: clear any leftover tree pause from older builds／other systems.
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
	if emit_cancel:
		cancelled.emit()


func _paint() -> void:
	var n := _pages.size()
	var i := clampi(_index, 0, maxi(0, n - 1))
	_index = i
	var page: Dictionary = _pages[i] if i < n else {}
	_title.text = Loc.t(String(page.get("title_key", "")))
	_body.text = Loc.t(String(page.get("body_key", "")))
	_page_lab.text = Loc.t("tut.modal.page", [i + 1, n])
	var path := String(page.get("image_path", ""))
	if path != "" and ResourceLoader.exists(path):
		_image.texture = load(path) as Texture2D
		_image.visible = true
	else:
		_image.texture = null
		_image.visible = false
	_prev_btn.disabled = i <= 0
	_prev_btn.text = Loc.t("tut.modal.prev")
	var last := i >= n - 1
	if last:
		_next_btn.text = Loc.t("tut.modal.close" if _review else "tut.modal.practice")
	else:
		_next_btn.text = Loc.t("tut.modal.next")


func _on_prev() -> void:
	if _index <= 0:
		return
	SfxBus.play("sfx_ui_move")
	_index -= 1
	_paint()


func _on_next() -> void:
	if _index >= _pages.size() - 1:
		SfxBus.play("sfx_ui_confirm")
		close_modal(false)
		finished.emit()
		return
	SfxBus.play("sfx_ui_move")
	_index += 1
	_paint()


## Use _input (not only unhandled) so ops-day player doesn't steal A first.
## Ignore JoypadMotion — stick axes spam move_*／ui_* and would blaze through pages.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	if event.is_echo() or not event.is_pressed():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		if _review:
			SfxBus.play("sfx_ui_cancel")
			close_modal(true)
		get_viewport().set_input_as_handled()
		return
	## D-PAD is on bag_slot_* in ops; still accept it here for page flip.
	if (
		event.is_action_pressed("ui_left")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("bag_slot_left")
	):
		_on_prev()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed("ui_right")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("bag_slot_right")
		or event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):
		_on_next()
		get_viewport().set_input_as_handled()
