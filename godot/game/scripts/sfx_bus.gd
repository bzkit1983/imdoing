extends Node
## Alpha SFX playback bus. Autoload `SfxBus`.
## Call `SfxBus.play("sfx_…")` at gameplay event edges.
## Players use PROCESS_MODE_ALWAYS so pause-menu SFX still work.

const SfxCatalog = preload("res://scripts/sfx_catalog.gd")

const POOL_SIZE := 12
const DEFAULT_VOL_DB := -4.0
const VOLUME_STEP := 0.1
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const SETTINGS_MUTED := "sfx_muted"
const SETTINGS_VOLUME := "sfx_volume"

var _streams: Dictionary = {} ## id -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _muted: bool = false
## Linear 0.0–1.0; applied to the SFX bus (independent of mute).
var _volume: float = 1.0
var _foot_cd: float = 0.0
var _scrub_cd: float = 0.0
var _stock_loop_cd: float = 0.0
var _overcarry_cd: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_bus()
	_preload_all()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPool_%d" % i
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = DEFAULT_VOL_DB
		add_child(p)
		_pool.append(p)


func _process(delta: float) -> void:
	if _foot_cd > 0.0:
		_foot_cd = maxf(0.0, _foot_cd - delta)
	if _scrub_cd > 0.0:
		_scrub_cd = maxf(0.0, _scrub_cd - delta)
	if _stock_loop_cd > 0.0:
		_stock_loop_cd = maxf(0.0, _stock_loop_cd - delta)
	if _overcarry_cd > 0.0:
		_overcarry_cd = maxf(0.0, _overcarry_cd - delta)


func set_muted(on: bool) -> void:
	_muted = on
	if on:
		for p in _pool:
			if p.playing:
				p.stop()
	_apply_bus()
	_save_settings()


func is_muted() -> bool:
	return _muted


func toggle_muted() -> bool:
	set_muted(not _muted)
	return _muted


func get_volume() -> float:
	return _volume


## Linear 0.0–1.0.
func set_volume(v: float) -> void:
	_volume = clampf(snappedf(v, VOLUME_STEP), 0.0, 1.0)
	_apply_bus()
	_save_settings()


## Nudge by ±1 step (10%). Returns new linear volume.
func nudge_volume(steps: int) -> float:
	set_volume(_volume + float(steps) * VOLUME_STEP)
	return _volume


func volume_percent() -> int:
	return int(round(_volume * 100.0))


func _apply_bus() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, _muted)
	if _volume <= 0.001:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(_volume))


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	_muted = bool(cf.get_value(SETTINGS_SECTION, SETTINGS_MUTED, false))
	_volume = clampf(float(cf.get_value(SETTINGS_SECTION, SETTINGS_VOLUME, 1.0)), 0.0, 1.0)
	_volume = snappedf(_volume, VOLUME_STEP)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH) # keep other keys if present
	cf.set_value(SETTINGS_SECTION, SETTINGS_MUTED, _muted)
	cf.set_value(SETTINGS_SECTION, SETTINGS_VOLUME, _volume)
	cf.save(SETTINGS_PATH)


## `force` plays even when muted (settings UI tip). Still respects bus volume.
func play(id: String, pitch: float = 1.0, vol_db: float = NAN, force: bool = false) -> void:
	if id == "" or (not force and _muted):
		return
	var stream: AudioStream = _streams.get(id) as AudioStream
	if stream == null:
		stream = _load_one(id)
		if stream == null:
			return
	var p := _next_player()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = DEFAULT_VOL_DB if is_nan(vol_db) else vol_db
	## Bypass bus mute for forced tips so volume steps stay audible while muted.
	if force and _muted:
		var idx := AudioServer.get_bus_index("SFX")
		if idx >= 0:
			AudioServer.set_bus_mute(idx, false)
			p.finished.connect(func() -> void:
				if _muted and idx >= 0:
					AudioServer.set_bus_mute(idx, true)
			, CONNECT_ONE_SHOT)
	p.play()


## Footsteps — rate-limited; walk≈0.32s, run≈0.22s.
func play_foot(running: bool) -> void:
	if _foot_cd > 0.0:
		return
	if running:
		_foot_cd = 0.22
		play("sfx_move_foot_run")
	else:
		_foot_cd = 0.32
		play("sfx_move_foot_walk")


## Clean scrub ticks — rate-limited.
func play_scrub() -> void:
	if _scrub_cd > 0.0:
		return
	_scrub_cd = 0.12
	play("sfx_clean_scrub")


## Near-shelf stock loop tip — rate-limited soft ticks.
func play_stock_loop() -> void:
	if _stock_loop_cd > 0.0:
		return
	_stock_loop_cd = 0.2
	play("sfx_shelf_stock_loop", 1.0, DEFAULT_VOL_DB - 8.0)


## Overcarry drag tip — soft, infrequent.
func play_overcarry() -> void:
	if _overcarry_cd > 0.0:
		return
	_overcarry_cd = 0.9
	play("sfx_move_overcarry", 1.0, DEFAULT_VOL_DB - 10.0)


func has_id(id: String) -> bool:
	return not SfxCatalog.entry(id).is_empty()


func catalog() -> Array[Dictionary]:
	return SfxCatalog.ENTRIES


func _preload_all() -> void:
	for e in SfxCatalog.ENTRIES:
		_load_one(String(e["id"]))


func _load_one(id: String) -> AudioStream:
	var path := SfxCatalog.path_for(id)
	if path == "":
		push_warning("SfxBus: unknown id %s" % id)
		return null
	if not ResourceLoader.exists(path):
		push_warning("SfxBus: missing %s" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("SfxBus: failed load %s" % path)
		return null
	_streams[id] = stream
	return stream


func _next_player() -> AudioStreamPlayer:
	var start := _pool_i
	for _i in _pool.size():
		var p := _pool[_pool_i]
		_pool_i = (_pool_i + 1) % _pool.size()
		if not p.playing:
			return p
	# All busy — steal next
	var steal := _pool[start]
	_pool_i = (start + 1) % _pool.size()
	return steal
