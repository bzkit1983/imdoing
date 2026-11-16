extends Node
## Prep layout probe. Fails when content rectangles overlap or leave the 720-tall canvas.
## Home, list pages, shop layout, confirm, and lobby are all checked.


const DemoScript = preload("res://scripts/demo.gd")
const ProductVersion = preload("res://scripts/product_version.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const PrepPages = preload("res://scripts/prep/prep_pages.gd")

const CANVAS_H := 724.0
const CANVAS_W := 1284.0

const PAGES: Array[String] = [
	"scenario",
	"home",
	"hub_char",
	"hub_goods",
	"hub_shop",
	"hub_sys",
	"stats",
	"look",
	"skills",
	"skill_set",
	"develop",
	"buy",
	"for_sale",
	"furn",
	"expand",
	"layout",
	"clerks",
	"locale",
	"sfx",
	"tasks",
	"rating_history",
	"confirm",
	"lobby",
	"lan_join",
	"steam_join",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("TEST_TOOLS=", ProductVersion.test_tools_enabled())
	print("px_btn(26)=", UiFont.px_btn(26), " px(26)=", UiFont.px(26))
	print("viewport=", get_viewport().get_visible_rect().size)
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
	var bad := false
	for page in PAGES:
		if prep.has_method("_show_page"):
			prep.call("_show_page", page)
		await get_tree().process_frame
		await get_tree().process_frame
		if _check(prep, page):
			bad = true
	if prep.has_method("_show_page"):
		prep.call("_show_page", "skills")
	PrepPages.fill_skill_pick(prep, 0)
	await get_tree().process_frame
	if _check(prep, "skill_pick"):
		bad = true
	prep.set("_qty_sku", "can")
	prep.set("_qty_boxes", 1)
	prep.set("_page", "buy")
	if prep.has_method("_refresh"):
		prep.call("_refresh")
	await get_tree().process_frame
	if _check(prep, "buy_qty"):
		bad = true
	if ProductVersion.test_tools_enabled():
		for page in ["test_tasks", "elite_test"]:
			prep.call("_show_page", page)
			await get_tree().process_frame
			if _check(prep, page):
				bad = true
	get_tree().quit(1 if bad else 0)


func _check(prep, page: String) -> bool:
	var rects: Array = _content_rects(prep)
	if page == "look":
		var preview := _look_rect(prep)
		if preview.size.x > 1.0 and preview.size.y > 1.0:
			rects.append(["LookPreview", preview])
	print("PAGE", page, " n=", rects.size())
	var bad := false
	if page == "home":
		var hub = prep.get("_hub_panel")
		var n := 0
		if hub:
			n = hub.get_child_count()
		print("home_tiles=", n)
		if n != 7:
			print("FAIL expected 7 hub tiles, got ", n)
			bad = true
		if _dump_home_gaps(prep):
			bad = true
	for i in rects.size():
		var name_a: String = rects[i][0]
		var a: Rect2 = rects[i][1]
		print("  ", name_a, " ", a)
		if a.position.x < -1.0 or a.position.y < -1.0 or a.end.x > CANVAS_W or a.end.y > CANVAS_H:
			print("FAIL clip ", page, " ", name_a, " ", a)
			bad = true
		for j in range(i + 1, rects.size()):
			var name_b: String = rects[j][0]
			var b: Rect2 = rects[j][1]
			var hit := a.intersection(b)
			if hit.size.x > 1.0 and hit.size.y > 1.0:
				print("FAIL overlap ", page, " ", name_a, " x ", name_b, " ", hit)
				bad = true
	return bad


func _content_rects(prep) -> Array:
	var keys: Array[String] = [
		"_title", "_back_btn", "_info", "_list", "_hub_panel", "_diff_bar", "_open_bar",
		"_grid", "_size_panel", "_stats_panel", "_qty_panel", "_lan_addr_edit", "_steam_lobby_edit",
	]
	var out: Array = []
	for key in keys:
		var node = prep.get(key)
		if node == null or not (node is Control) or not node.visible:
			continue
		var r := Rect2(node.position, node.size)
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		out.append([key, r])
	return out


func _look_rect(prep) -> Rect2:
	var root = prep.get("_look_preview_root")
	if root == null or not is_instance_valid(root):
		return Rect2()
	var spr = prep.get("_look_preview_spr")
	if spr == null or not is_instance_valid(spr):
		return Rect2(root.position + Vector2(-20, -20), Vector2(140, 180))
	var frames: SpriteFrames = spr.sprite_frames
	var tex: Texture2D = null
	if frames != null and frames.has_animation(spr.animation):
		tex = frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return Rect2(root.position + Vector2(-20, -20), Vector2(140, 180))
	var origin: Vector2 = root.position + spr.position + spr.offset
	return Rect2(origin, tex.get_size() * spr.scale)


func _dump_home_gaps(prep) -> bool:
	var bad := false
	var hub = prep.get("_hub_panel")
	var diff = prep.get("_diff_bar")
	var openb = prep.get("_open_bar")
	if hub == null or not hub.visible:
		return false
	var hub_bottom := float(hub.position.y) + float(hub.size.y)
	if diff and diff.visible:
		var diff_top := float(diff.position.y)
		print("gap_hub_diff=", diff_top - hub_bottom)
		if openb and openb.visible:
			var diff_bottom := diff_top + float(diff.size.y)
			print("gap_diff_open=", float(openb.position.y) - diff_bottom)
	if diff:
		for c in diff.get_children():
			if c is Button:
				var fs: int = c.get_theme_font_size("font_size")
				print("btn ", c.name, " font=", fs, " size=", c.size)
				if fs > 40:
					print("FAIL diff font too large for DIFF_H")
					bad = true
	return bad
