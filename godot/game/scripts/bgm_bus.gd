extends Node
## BGM playback bus. Autoload node name: `BgmBus`.
## Prefer `BgmBusScript.bus()` (preload this script) so callers parse without the
## autoload global — editor／LSP may lag after adding a new autoload.
## Phase themes: prep / operation / elite override. Players use PROCESS_MODE_ALWAYS.

const VOLUME_STEP := 0.1
const FADE_SEC := 0.4
## Base mix vs full scale (linear 50% ≈ −6 dB); user bus volume stacks on top.
const DEFAULT_VOL_DB := -6.0
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const SETTINGS_MUTED := "bgm_muted"
const SETTINGS_VOLUME := "bgm_volume"

const TRACK_PREP := "PrepareShop"
const TRACK_OP: Array[String] = ["Operation1", "Operation2"]
const TRACK_ELITE: Array[String] = ["EliteCustomer1", "EliteCustomer2"]
const TRACK_BOSS := "BossBattle1"
const BGM_DIR := "res://audio/bgm/"
const AUTOLOAD_PATH := "/root/BgmBus"


## Singleton instance (autoload). Safe from static callers via preload.
static func bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(AUTOLOAD_PATH)

var _streams: Dictionary = {} ## id -> AudioStream
var _player: AudioStreamPlayer
var _fade_tween: Tween
var _muted: bool = false
## Linear 0.0–1.0; applied to the Music bus (independent of mute).
var _volume: float = 1.0

## Current theme: "" | "prep" | "operation" | "elite" | "boss"
var _theme: String = ""
## Day-locked Operation track id (Operation1 / Operation2).
var _operation_track: String = ""
## Elite track currently (or last) selected for this elite spell.
var _elite_track: String = ""
## Desired track while muted — resume on unmute.
var _pending_track: String = ""
var _suspended := false
## Minigame bed (e.g. fishing_taro): replaces the Music player until cleared.
var _override_stream: AudioStream = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_bus()
	_preload_all()
	_player = AudioStreamPlayer.new()
	_player.name = "BgmPlayer"
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.volume_db = DEFAULT_VOL_DB
	add_child(_player)


func set_muted(on: bool) -> void:
	_muted = on
	_apply_bus()
	if on:
		if _player.playing:
			_player.stop()
		_kill_fade()
		_player.volume_db = DEFAULT_VOL_DB
	elif _override_stream != null:
		_player.stream = _override_stream
		_player.volume_db = DEFAULT_VOL_DB
		_player.stream_paused = false
		_player.play()
	elif _pending_track != "":
		_start_track(_pending_track, false)
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


func play_prep() -> void:
	_theme = "prep"
	_operation_track = ""
	_elite_track = ""
	_switch_to(TRACK_PREP)


## Pick a new Operation track for the day (or keep if already set and `reshuffle` false).
func play_operation(reshuffle: bool = true) -> void:
	_theme = "operation"
	_elite_track = ""
	if reshuffle or _operation_track == "":
		_operation_track = String(TRACK_OP[randi() % TRACK_OP.size()])
	_switch_to(_operation_track)


func enter_elite() -> void:
	if _theme == "elite" or _theme == "boss":
		return
	## Remember operation bed if we somehow entered elite without a day pick.
	if _operation_track == "":
		_operation_track = String(TRACK_OP[randi() % TRACK_OP.size()])
	_theme = "elite"
	_elite_track = String(TRACK_ELITE[randi() % TRACK_ELITE.size()])
	_switch_to(_elite_track)


## Restore the day's Operation track after the last elite leaves.
func exit_elite_if_clear() -> void:
	if _theme != "elite":
		return
	_theme = "operation"
	_elite_track = ""
	if _operation_track == "":
		_operation_track = String(TRACK_OP[randi() % TRACK_OP.size()])
	_switch_to(_operation_track)


## Boss battle day: override with BossBattle1 until prep／day end.
func enter_boss() -> void:
	if _theme == "boss":
		return
	if _operation_track == "":
		_operation_track = String(TRACK_OP[randi() % TRACK_OP.size()])
	_theme = "boss"
	_elite_track = ""
	_switch_to(TRACK_BOSS)


func stop() -> void:
	_theme = ""
	_pending_track = ""
	_kill_fade()
	if _player != null and _player.playing:
		_player.stop()


func current_theme() -> String:
	return _theme


func set_suspended(suspended: bool) -> void:
	## Override bed owns the player — ignore pause/resume from other minigames.
	if _override_stream != null:
		return
	if _player == null or _suspended == suspended:
		return
	_suspended = suspended
	_kill_fade()
	_player.volume_db = DEFAULT_VOL_DB
	_player.stream_paused = suspended
	if not suspended and not _muted and _pending_track != "":
		_start_track(_pending_track, false)


## Swap Music player to a one-off bed (Prep minigames). Call clear_override() on exit.
func play_override(stream: AudioStream) -> void:
	if _player == null or stream == null:
		return
	_override_stream = _with_loop(stream)
	_suspended = true
	_kill_fade()
	_player.stream_paused = false
	_player.stream = _override_stream
	_player.volume_db = DEFAULT_VOL_DB
	if _muted:
		_player.stop()
		return
	_player.play()


func clear_override() -> void:
	if _override_stream == null:
		return
	_override_stream = null
	_suspended = false
	_kill_fade()
	_player.stream_paused = false
	if _muted:
		_player.stop()
		return
	if _pending_track != "":
		_start_track(_pending_track, false)
	elif _player.playing:
		_player.stop()


## Godot 4.7 WAV: loop_end=-1 / unset plays 0 frames (silent). Use sample count.
func _with_loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		var bytes_per_frame := 2
		match wav.format:
			AudioStreamWAV.FORMAT_8_BITS:
				bytes_per_frame = 1
			AudioStreamWAV.FORMAT_IMA_ADPCM:
				bytes_per_frame = 1
			_:
				bytes_per_frame = 2
		if wav.stereo:
			bytes_per_frame *= 2
		wav.loop_begin = 0
		wav.loop_end = int(wav.data.size() / maxi(bytes_per_frame, 1))
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav
	if stream is AudioStreamMP3:
		var mp3 := (stream as AudioStreamMP3).duplicate() as AudioStreamMP3
		mp3.loop = true
		return mp3
	return stream


## Settings tip: ensure Music bus briefly audible at current volume.
func preview_volume() -> void:
	if _player == null or _suspended:
		return
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0 and _muted:
		AudioServer.set_bus_mute(idx, false)
		get_tree().create_timer(0.35, true, false, true).timeout.connect(func() -> void:
			if _muted and idx >= 0:
				AudioServer.set_bus_mute(idx, true)
		, CONNECT_ONE_SHOT)
	if not _player.playing and _pending_track != "":
		var stream: AudioStream = _streams.get(_pending_track) as AudioStream
		if stream != null:
			_player.stream = stream
			_player.volume_db = DEFAULT_VOL_DB
			_player.play()
			get_tree().create_timer(0.35, true, false, true).timeout.connect(func() -> void:
				if _muted and _player != null and _player.playing:
					_player.stop()
			, CONNECT_ONE_SHOT)


func _switch_to(track_id: String) -> void:
	_pending_track = track_id
	if _muted:
		if _player != null and _player.playing:
			_player.stop()
		return
	_start_track(track_id, true)


func _start_track(track_id: String, fade: bool) -> void:
	if _suspended or _override_stream != null:
		return
	var stream: AudioStream = _streams.get(track_id) as AudioStream
	if stream == null:
		stream = _load_one(track_id)
		if stream == null:
			return
	_pending_track = track_id
	## Same stream already playing — keep position.
	if _player.playing and _player.stream == stream:
		return
	_kill_fade()
	if fade and _player.playing:
		_fade_tween = create_tween()
		_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade_tween.tween_property(_player, "volume_db", -40.0, FADE_SEC * 0.5)
		_fade_tween.tween_callback(func() -> void:
			_player.stop()
			_player.stream = stream
			_player.volume_db = -40.0
			_player.play()
		)
		_fade_tween.tween_property(_player, "volume_db", DEFAULT_VOL_DB, FADE_SEC * 0.5)
	else:
		_player.stream = stream
		_player.volume_db = DEFAULT_VOL_DB
		_player.play()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _apply_bus() -> void:
	var idx := AudioServer.get_bus_index("Music")
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


func _preload_all() -> void:
	_load_one(TRACK_PREP)
	for id in TRACK_OP:
		_load_one(String(id))
	for id in TRACK_ELITE:
		_load_one(String(id))
	_load_one(TRACK_BOSS)


func _load_one(id: String) -> AudioStream:
	var path := BGM_DIR + id + ".mp3"
	if not ResourceLoader.exists(path):
		push_warning("BgmBus: missing %s" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("BgmBus: failed load %s" % path)
		return null
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_streams[id] = stream
	return stream
