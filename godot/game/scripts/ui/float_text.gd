extends Node2D
## Short rising float number above a world actor (ops feedback).
## Color follows player-facing sign: positive = green, negative = red.
## Dissat callers pass display_value = -internal_delta (patience polarity).
## Concurrent floats near the same head stack upward so they stay readable.

const UiFont = preload("res://scripts/ui_font.gd")

const COLOR_GOOD := Color("5dce7a")
const COLOR_BAD := Color("e85d5d")
const RISE_PX := 42.0
const DURATION := 0.85
## Line gap ≥ world font so stacked +$ / +XP / dissat do not cover each other.
const STAGGER_Y := 30.0
const STACK_GROUP := "ops_float"
## Match new spawns to in-flight floats over the same actor head.
const STACK_X := 52.0
const STACK_Y := 80.0


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
	UiFont.apply_label(lab, UiFont.WORLD)
	var col := COLOR_GOOD if shown > 0 else COLOR_BAD
	lab.add_theme_color_override("font_color", col)
	lab.position = Vector2(-40, -8)
	lab.size = Vector2(80, 28)
	add_child(lab)
	var delay := mini(0.12, 0.04 * float(slot))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - RISE_PX, DURATION).set_delay(delay)
	tw.tween_property(lab, "modulate:a", 0.0, DURATION).set_delay(delay + DURATION * 0.25)
	tw.chain().tween_callback(queue_free)


func _format(shown: int, kind: String) -> String:
	var sign := "+" if shown > 0 else ""
	match kind:
		"money":
			return "$%s%d" % [sign, shown]
		"xp":
			return "%s%d XP" % [sign, shown]
		_:
			return "%s%d" % [sign, shown]
