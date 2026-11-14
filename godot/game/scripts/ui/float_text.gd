extends Node2D
## Short rising float number above a world actor (ops feedback).
## Color follows player-facing sign: positive = green, negative = red.
## Dissat callers pass display_value = -internal_delta (patience polarity).
## Concurrent floats near the same head stack upward so they stay readable.
## Tech-review J2: instances are pooled.

const UiFont = preload("res://scripts/ui_font.gd")

const COLOR_GOOD := Color("5dce7a")
const COLOR_BAD := Color("e85d5d")
const COLOR_OUTLINE := Color(0.06, 0.08, 0.07, 0.92)
## Larger than UiFont.WORLD so head pops read clearly over sprites.
const FONT_SIZE := 30
const RISE_PX := 52.0
## Total life; opaque hold then fade so the number stays readable longer.
const DURATION := 1.25
const HOLD_FRAC := 0.45
const POP_SCALE := 1.18
## Line gap ≥ float font so stacked +$ / +XP / dissat do not cover each other.
const STAGGER_Y := 34.0
const STACK_GROUP := "ops_float"
## Match new spawns to in-flight floats over the same actor head.
const STACK_X := 56.0
const STACK_Y := 96.0

const POOL_CAP := 32
static var _pool: Array = []

var _lab: Label
var _tween: Tween


static func spawn(parent: Node, world_pos: Vector2, display_value: float, kind: String = "", stagger: int = 0) -> void:
	if parent == null:
		return
	var shown := int(round(display_value))
	if shown == 0:
		return
	var n: Node2D = _acquire()
	n.name = "FloatText"
	n.z_index = 40
	var slot := maxi(stagger, _stack_index(parent, world_pos))
	n.visible = true
	n.modulate = Color.WHITE
	n.scale = Vector2(POP_SCALE, POP_SCALE)
	parent.add_child(n)
	n.global_position = world_pos + Vector2(0, -slot * STAGGER_Y)
	if not n.is_in_group(STACK_GROUP):
		n.add_to_group(STACK_GROUP)
	n.call("_begin", shown, kind, slot)


static func _acquire() -> Node2D:
	while not _pool.is_empty():
		var n = _pool.pop_back()
		if n != null and is_instance_valid(n):
			return n as Node2D
	return (load("res://scripts/ui/float_text.gd") as Script).new() as Node2D


static func spawn_on(actor: Node2D, display_value: float, kind: String = "", stagger: int = 0) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var parent: Node = actor.get_parent()
	if parent == null:
		parent = actor
	var at := actor.global_position + Vector2(0, -36)
	spawn(parent, at, display_value, kind, stagger)


static func spawn_xp(actor: Node2D, amount: int, stagger: int = 0) -> void:
	if amount <= 0:
		return
	spawn_on(actor, float(amount), "xp", stagger)


static func spawn_money(actor: Node2D, amount: int, stagger: int = 0) -> void:
	if amount <= 0:
		return
	spawn_on(actor, float(amount), "money", stagger)


## internal_delta > 0 means anger rose → player sees negative (red).
static func spawn_dissat(actor: Node2D, internal_delta: float, stagger: int = 0) -> void:
	if absf(internal_delta) < 0.05:
		return
	spawn_on(actor, -internal_delta, "dissat", stagger)


static func spawn_rating(actor: Node2D, delta: int, stagger: int = 0) -> void:
	if delta == 0:
		return
	spawn_on(actor, float(delta), "rating", stagger)


## How many live floats already sit near this head (same-frame stack + overlap).
static func _stack_index(parent: Node, at: Vector2) -> int:
	var count := 0
	for c in parent.get_children():
		if not (c is Node2D) or not (c as Node2D).is_in_group(STACK_GROUP):
			continue
		var p: Vector2 = (c as Node2D).global_position
		if absf(p.x - at.x) <= STACK_X and absf(p.y - at.y) <= STACK_Y:
			count += 1
	return count


func _begin(shown: int, kind: String, slot: int = 0) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	if _lab == null:
		_lab = Label.new()
		_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lab.position = Vector2(-56, -12)
		_lab.size = Vector2(112, 36)
		add_child(_lab)
	_lab.modulate = Color.WHITE
	_lab.text = _format(shown, kind)
	UiFont.apply_label(_lab, FONT_SIZE)
	var col := COLOR_GOOD if shown > 0 else COLOR_BAD
	_lab.add_theme_color_override("font_color", col)
	_lab.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_lab.add_theme_constant_override("outline_size", 6)
	scale = Vector2(POP_SCALE, POP_SCALE)
	var delay := mini(0.12, 0.04 * float(slot))
	var hold := DURATION * HOLD_FRAC
	var fade := DURATION - hold
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", position.y - RISE_PX, DURATION).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_lab, "modulate:a", 0.0, fade).set_delay(delay + hold)
	_tween.chain().tween_callback(_recycle)


func _recycle() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	visible = false
	if is_in_group(STACK_GROUP):
		remove_from_group(STACK_GROUP)
	if get_parent() != null:
		get_parent().remove_child(self)
	if _pool.size() >= POOL_CAP:
		queue_free()
		return
	_pool.append(self)


func _format(shown: int, kind: String) -> String:
	var sign := "+" if shown > 0 else ""
	match kind:
		"money":
			return "$%s%d" % [sign, shown]
		"xp":
			return "%s%d XP" % [sign, shown]
		"rating":
			return Loc.t("float.rating", [sign, shown])
		"dissat":
			return Loc.t("float.dissat", [sign, shown])
		_:
			return "%s%d" % [sign, shown]
