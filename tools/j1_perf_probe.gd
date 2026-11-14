extends SceneTree
## Headless J1 probe: load living-line demo, sample Performance monitors.
## Usage (repo root):
##   GODOT=/path/to/Godot ./tools/j1_perf_probe.sh
## Prints J1_PROBE lines for docs/alpha/perf-baseline-j1.md.

const SAMPLE_SEC := 4.0
const WARMUP_SEC := 2.0


func _initialize() -> void:
	call_deferred("_run")


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
	var phase := ""
	var guest_cap := -1
	var guests := -1
	var thieves := -1
	var clones := -1
	if host != null:
		phase = String(host.get("phase"))
		if host.has_method("guest_cap") == false and host.get("state") != null:
			var st = host.get("state")
			if st != null and st.has_method("guest_cap"):
				guest_cap = int(st.call("guest_cap"))
		if host.has_method("guest_count"):
			guests = int(host.call("guest_count"))
		if host.has_method("thief_count"):
			thieves = int(host.call("thief_count"))
		if host.has_method("shadow_clones"):
			clones = (host.call("shadow_clones") as Array).size()

	var n := 0
	var sum_ft := 0.0
	var sum_proc := 0.0
	var sum_phys := 0.0
	var max_ft := 0.0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < int(SAMPLE_SEC * 1000.0):
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
	print("J1_PROBE kind=headless_demo_settle")
	print("J1_PROBE note=Not full-shop dual-player; demo settle (often prep). See docs/alpha/perf-baseline-j1.md for full-load recipe.")
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
