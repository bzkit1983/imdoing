extends Node
## Dump prep home chrome positions after layout; exit 1 on overlap / off-screen open.


const DemoScript = preload("res://scripts/demo.gd")
const ProductVersion = preload("res://scripts/product_version.gd")
const UiFont = preload("res://scripts/ui_font.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("TEST_TOOLS=", ProductVersion.test_tools_enabled())
	print("px_btn(26)=", UiFont.px_btn(26), " px(26)=", UiFont.px(26))
	var demo: Node = DemoScript.new()
	get_tree().root.add_child(demo)
	await get_tree().process_frame
	await get_tree().process_frame
	var prep = demo.get("_prep")
	if prep == null:
		print("FAIL no prep")
		get_tree().quit(1)
		return
	if demo.state != null:
		demo.state.apply_scenario(2)
	if prep.has_method("_show_page"):
		prep.call("_show_page", "home")
	await get_tree().process_frame
	await get_tree().process_frame
	var hub = prep.get("_hub_panel")
	var diff = prep.get("_diff_bar")
	var openb = prep.get("_open_bar")
	print("page=", prep.get("_page"), " hub_n=", hub.get_child_count() if hub else -1)
	_dump("Hub", hub)
	_dump("DiffBar", diff)
	_dump("OpenBar", openb)
	var bad := false
	if hub and hub.get_child_count() != 5:
		print("FAIL expected 5 hub tiles, got ", hub.get_child_count())
		bad = true
	if hub and diff and hub.visible and diff.visible:
		var hub_bottom := float(hub.position.y) + float(hub.size.y)
		var diff_top := float(diff.position.y)
		var diff_bottom := diff_top + float(diff.size.y)
		var open_top := float(openb.position.y) if openb else -1.0
		var open_bottom := open_top + float(openb.size.y) if openb else -1.0
		print("hub_bottom=", hub_bottom, " diff_top=", diff_top, " gap_hub_diff=", diff_top - hub_bottom)
		print("diff_bottom=", diff_bottom, " open_top=", open_top, " gap_diff_open=", open_top - diff_bottom)
		if diff_top < hub_bottom - 1.0:
			print("OVERLAP hub/diff")
			bad = true
		if openb and open_top < diff_bottom - 1.0:
			print("OVERLAP diff/open")
			bad = true
		## Design canvas is 720 tall; open bar must stay on the home strip.
		if openb and open_bottom > 720.0 + 1.0:
			print("FAIL open bar below 720 (", open_bottom, ")")
			bad = true
	if diff:
		for c in diff.get_children():
			if c is Button:
				var fs: int = c.get_theme_font_size("font_size")
				print("btn ", c.name, " font=", fs, " size=", c.size)
				if fs > 40:
					print("FAIL diff font too large for DIFF_H")
					bad = true
	get_tree().quit(1 if bad else 0)


func _dump(tag: String, n) -> void:
	if n == null:
		print(tag, " null")
		return
	print(tag, " vis=", n.visible, " pos=", n.position, " size=", n.size)
