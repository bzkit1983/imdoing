extends Node2D
## Short rising float number above a world actor (ops feedback).
## Color follows player-facing sign: positive = green, negative = red.
## Dissat callers pass display_value = -internal_delta (patience polarity).
## Concurrent floats near the same head stack upward so they stay readable.

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


static func spawn(parent: Node, world_pos: Vector2, display_value: float, kind: String = "", stagger: int = 0) -> void:
	if parent == null:
		return
	var shown := int(round(display_value))
	if shown == 0:
		return
	var script: Script = load("res://scripts/ui/float_text.gd") as Script
	var n: Node2D = script.new() as Node2D
	n.name = "FloatText"
	n.z_index = 40
	var slot := maxi(stagger, _stack_index(parent, world_pos))
	n.global_position = world_pos + Vector2(0, -slot * STAGGER_Y)
	n.add_to_group(STACK_GROUP)
	parent.add_child(n)
	n.call("_begin", shown, kind, slot)


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
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.text = _format(shown, kind)
	UiFont.apply_label(lab, FONT_SIZE)
	var col := COLOR_GOOD if shown > 0 else COLOR_BAD
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	lab.add_theme_constant_override("outline_size", 6)
	lab.position = Vector2(-56, -12)
	lab.size = Vector2(112, 36)
	scale = Vector2(POP_SCALE, POP_SCALE)
	add_child(lab)
	var delay := mini(0.12, 0.04 * float(slot))
	var hold := DURATION * HOLD_FRAC
	var fade := DURATION - hold
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - RISE_PX, DURATION).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lab, "modulate:a", 0.0, fade).set_delay(delay + hold)
	tw.chain().tween_callback(queue_free)


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
