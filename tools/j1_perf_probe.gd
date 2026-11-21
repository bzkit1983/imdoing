extends SceneTree
## Headless J1 probe: load living-line demo, sample Performance monitors.
## Usage (repo root):
##   GODOT=/path/to/Godot ./tools/j1_perf_probe.sh
##   GODOT=/path/to/Godot ./tools/j1_perf_probe.sh -- --load
## Prints J1_PROBE lines for docs/alpha/perf-baseline-j1.md.

const SAMPLE_SEC := 4.0
const WARMUP_SEC := 2.0
const LOAD_SAMPLE_SEC := 8.0


func _initialize() -> void:
	call_deferred("_run")


func _want_load() -> bool:
	for a in OS.get_cmdline_user_args():
		if String(a) == "--load" or String(a) == "load":
			return true
	return false


func _run() -> void:
	var err := change_scene_to_file("res://scenes/demo.tscn")
	if err != OK:
		print("J1_PROBE fail change_scene err=", err)
		quit(2)
		return
	await process_frame
	await process_frame
	## Warmup: let Autoloads + demo _ready settle.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(WARMUP_SEC * 1000.0):
		await process_frame

	var host := _find_host()
	var kind := "headless_demo_settle"
	var note := "Not full-shop dual-player; demo settle (often prep). See docs/alpha/perf-baseline-j1.md for full-load recipe."
	if _want_load() and host != null:
		await _force_load(host)
		## Let AI / physics tick under load before sampling.
		var tw := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tw < 2000:
			await process_frame
		kind = "headless_desktop_load"
		note = "Forced open + scenario3 cap + guests + shadow clones Lv3; single seat headless (not Editor Profiler dual-player)."

	var phase := ""
	var guest_cap := -1
	var guests := -1
	var thieves := -1
	var clones := -1
	if host != null:
		phase = String(host.get("phase"))
		if host.get("state") != null:
			var st = host.get("state")
			if st != null and st.has_method("guest_cap"):
				guest_cap = int(st.call("guest_cap"))
		if host.has_method("guest_count"):
			guests = int(host.call("guest_count"))
		if host.has_method("thief_count"):
			thieves = int(host.call("thief_count"))
		if host.has_method("shadow_clones"):
			clones = (host.call("shadow_clones") as Array).size()

	var sample_sec := LOAD_SAMPLE_SEC if kind == "headless_desktop_load" else SAMPLE_SEC
	var n := 0
	var sum_ft := 0.0
	var sum_proc := 0.0
	var sum_phys := 0.0
	var max_ft := 0.0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < int(sample_sec * 1000.0):
		await process_frame
		var fps := float(Performance.get_monitor(Performance.TIME_FPS))
		## TIME_FPS is fps; derive frame ms when > 0.
		var frame_ms := 0.0 if fps <= 0.001 else 1000.0 / fps
		var proc_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		var phys_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		sum_ft += frame_ms
		sum_proc += proc_ms
		sum_phys += phys_ms
		if frame_ms > max_ft:
			max_ft = frame_ms
		n += 1

	if n <= 0:
		print("J1_PROBE fail no samples")
		quit(3)
		return

	var obj := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var mem := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)

	print("J1_PROBE ok")
	print("J1_PROBE kind=", kind)
	print("J1_PROBE note=", note)
	print("J1_PROBE samples=", n)
	print("J1_PROBE phase=", phase)
	print("J1_PROBE guest_cap=", guest_cap)
	print("J1_PROBE guests=", guests)
	print("J1_PROBE thieves=", thieves)
	print("J1_PROBE shadow_clones=", clones)
	print("J1_PROBE avg_frame_ms=", snapped(sum_ft / float(n), 0.01))
	print("J1_PROBE max_frame_ms=", snapped(max_ft, 0.01))
	print("J1_PROBE avg_process_ms=", snapped(sum_proc / float(n), 0.01))
	print("J1_PROBE avg_physics_ms=", snapped(sum_phys / float(n), 0.01))
	print("J1_PROBE nodes=", obj)
	print("J1_PROBE resources=", res)
	print("J1_PROBE static_mem_mib=", snapped(mem, 0.1))
	quit(0)


func _force_load(host: Node) -> void:
	var st = host.get("state")
	if st != null and st.has_method("apply_scenario"):
		st.call("apply_scenario", 3)
	## Build day world (creates Customers node, pathfinder, players).
	if host.has_method("_begin_day"):
		host.call("_begin_day")
		await process_frame
		await process_frame
		await process_frame
	## Ensure sellable stock so guest spawn can succeed.
	if st != null:
		var stock = st.get("stock")
		if stock is Dictionary:
			for sku in ["can", "snack", "milk", "veg"]:
				if int(stock.get(sku, 0)) < 20:
					stock[sku] = 40
	host.set("phase", "open")
	## Spawn guests up to cap (ignore_cap false uses guest_cap).
	if host.has_method("_spawn_customer"):
		var cap := 10
		if st != null and st.has_method("guest_cap"):
			cap = int(st.call("guest_cap"))
		var guard := 0
		while int(host.call("guest_count")) < cap and guard < cap + 5:
			if not bool(host.call("_spawn_customer", false)):
				## Retry once with ignore_cap if sellable blocked mid-loop.
				if not bool(host.call("_spawn_customer", true)):
					break
			guard += 1
			await process_frame
	if host.has_method("cast_shadow_clone"):
		host.call("cast_shadow_clone", 3, 0)
		await process_frame
		await process_frame


func _find_host() -> Node:
	var root_n := root
	if root_n == null:
		return null
	## demo.tscn root is usually the GameHost/demo node.
	for c in root_n.get_children():
		if c != null and (c.has_method("is_game_host") or c.has_method("guest_count")):
			return c
		for g in c.get_children():
			if g != null and (g.has_method("is_game_host") or g.has_method("guest_count")):
				return g
	return root_n.get_child(0) if root_n.get_child_count() > 0 else null
