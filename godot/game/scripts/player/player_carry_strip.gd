extends Node2D
## Overhead carry preview: [prev] ← [focus] → [next]

const SkuIcons = preload("res://scripts/sku_icons.gd")
const UiFont = preload("res://scripts/ui_font.gd")

var host: CharacterBody2D
var _visible_until: float = 0.0
var _force: bool = false

const ICON := 28.0
const Y := -96.0


func setup(p_host: CharacterBody2D) -> void:
	host = p_host
	z_index = 30


func pulse() -> void:
	_force = true
	_visible_until = Time.get_ticks_msec() / 1000.0 + 1.25


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	var inv = host.get("inventory")
	if inv == null or not inv.has_method("count") or int(inv.count()) <= 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not _force and now > _visible_until:
		## Still show while cycling recently; otherwise hide when idle with goods.
		## Plan: show when holding goods — keep visible while count > 0 for readability.
		pass
	_force = false
	var focus_i := int(inv.focus_index)
	var n: int = inv.slots.size() if inv.get("slots") != null else 0
	if n <= 0 or focus_i < 0:
		return
	var prev_i := focus_i - 1
	var next_i := focus_i + 1
	var entries: Array = []
	if prev_i >= 0:
		entries.append({"i": prev_i, "x": -52.0, "focus": false})
	entries.append({"i": focus_i, "x": 0.0, "focus": true})
	if next_i < n:
		entries.append({"i": next_i, "x": 52.0, "focus": false})
	var font := UiFont.font()
	draw_string(font, Vector2(-70, Y - 18), "←", HORIZONTAL_ALIGNMENT_LEFT, 20, UiFont.px(18), Color("f4d35e"))
	draw_string(font, Vector2(58, Y - 18), "→", HORIZONTAL_ALIGNMENT_LEFT, 20, UiFont.px(18), Color("f4d35e"))
	for e in entries:
		var slot: Dictionary = inv.slots[int(e["i"])]
		var sid := String(slot.get("id", ""))
		var cnt := int(slot.get("count", 0))
		var p := Vector2(float(e["x"]), Y)
		var focus: bool = bool(e["focus"])
		var sc := 1.25 if focus else 0.9
		var sz := ICON * sc
		var bg := Color(0.12, 0.14, 0.1, 0.9) if focus else Color(0.05, 0.06, 0.05, 0.75)
		var ring := Color("f4d35e") if focus else Color("6a6a6a")
		draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), bg)
		draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), ring, false, 2.0 if focus else 1.0)
		if sid != "":
			var tex := SkuIcons.texture(sid)
			if tex != null:
				draw_texture_rect(tex, Rect2(p - Vector2(sz, sz) * 0.4, Vector2(sz, sz) * 0.8), false)
		if cnt > 0:
			draw_string(
				font,
				p + Vector2(4, sz * 0.35),
				"×%d" % cnt,
				HORIZONTAL_ALIGNMENT_LEFT,
				40,
				UiFont.px(14),
				Color.WHITE,
			)
