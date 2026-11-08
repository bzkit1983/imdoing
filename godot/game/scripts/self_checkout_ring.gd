extends Line2D
## World-space duration indicator. Deliberately independent of customer time scaling.
const Tuning = preload("res://scripts/tuning.gd")
const DURATION := 15.0
const RADIUS := 5.0 * Tuning.BODY_LENGTH

var host: Node
var elapsed: float = 0.0


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


func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or str(host.get("phase")) in ["closed", "prep"]:
		hide()
		queue_free()
		return
	if host.has_method("asking_early_close") and host.asking_early_close():
		return
	elapsed += delta
	if elapsed >= DURATION:
		hide()
		queue_free()
		return
	# Brightness pulses gently; radius and circumference never count down.
	default_color.a = 0.55 + 0.10 * sin(TAU * elapsed / 2.0)
