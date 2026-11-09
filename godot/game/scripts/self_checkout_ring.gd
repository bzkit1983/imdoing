extends Line2D
## World-space duration indicator. Deliberately independent of customer time scaling.
const Tuning = preload("res://scripts/tuning.gd")
const DURATION := 15.0
const MARKER_DURATION := 5.0
const RADIUS := 5.0 * Tuning.BODY_LENGTH

var host: Node
var elapsed: float = 0.0
var _marker: Node2D


static func spawn(game: Node, at: Vector2) -> Line2D:
	var script: Script = load("res://scripts/self_checkout_ring.gd")
	var ring: Line2D = script.new()
	ring.host = game
	game.add_child(ring)
	ring.global_position = at
	return ring


func _ready() -> void:
	name = "SelfCheckoutRing"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Floor is -8; furniture, walls and characters are drawn above this ring.
	z_index = -7
	width = 2.5
	antialiased = true
	closed = true
	default_color = Color(0.25, 0.95, 0.72, 0.55)
	for i in 64:
		var angle := TAU * float(i) / 64.0
		add_point(Vector2(cos(angle), sin(angle)) * RADIUS)
	_setup_marker()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or str(host.get("phase")) in ["closed", "prep"]:
		hide()
		queue_free()
		return
	if host.has_method("asking_early_close") and host.asking_early_close():
		return
	elapsed += delta
	if elapsed >= MARKER_DURATION and is_instance_valid(_marker):
		_marker.free()
		_marker = null
	if elapsed >= DURATION:
		hide()
		queue_free()
		return
	# Brightness pulses gently; radius and circumference never count down.
	default_color.a = 0.55 + 0.10 * sin(TAU * elapsed / 2.0)


func _setup_marker() -> void:
	# Decorative planted flag: no collision, timer label or gameplay effect.
	_marker = Node2D.new()
	_marker.name = "ActivationFlag"
	_marker.z_index = 8
	add_child(_marker)
	var base := Polygon2D.new()
	base.color = Color(0.05, 0.20, 0.16, 0.65)
	var base_points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		base_points.append(Vector2(cos(angle) * 10.0, sin(angle) * 4.0))
	base.polygon = base_points
	_marker.add_child(base)
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -48)])
	pole.width = 3.0
	pole.default_color = Color(0.85, 0.94, 0.90)
	pole.antialiased = true
	_marker.add_child(pole)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(2, -47), Vector2(28, -44), Vector2(23, -34), Vector2(28, -24), Vector2(2, -27)])
	flag.color = Color(0.15, 0.80, 0.57, 0.95)
	_marker.add_child(flag)
	var symbol := Label.new()
	symbol.name = "DollarSymbol"
	symbol.text = "$"
	symbol.position = Vector2(4, -46)
	symbol.size = Vector2(18, 21)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.add_theme_font_override("font", preload("res://scripts/ui_font.gd").font())
	symbol.add_theme_font_size_override("font_size", 14)
	symbol.add_theme_color_override("font_color", Color.WHITE)
	_marker.add_child(symbol)
