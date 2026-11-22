extends RefCounted

const AUDIO_PATH := "res://audio/bgm/metal_rush_trial.wav"
const BEAT := 60.0 / 140.0
const OFFSET := 0.0
const DURATION := 112 * BEAT
const PERFECT_WINDOW := 0.055
const GOOD_WINDOW := 0.120

var notes: Array[Vector2] = []
var resolved := {}
var perfect := 0
var good := 0
var miss := 0
var combo := 0
var best := 0
var next_miss := 0


func _init() -> void:
	var riff := [0, 1, 3, 2, 1, 2, 0, 3]
	for i in 48:
		notes.append(Vector2(OFFSET + (4 + i + floori(i / 8.0)) * BEAT, riff[i % 8]))
	for phrase in 6:
		for i in 4:
			notes.append(Vector2(OFFSET + (60 + phrase * 9 + i * 0.5) * BEAT, riff[(phrase + i) % 8]))


func expire(time: float) -> void:
	while next_miss < notes.size() and time - notes[next_miss].x > GOOD_WINDOW:
		if not resolved.has(next_miss):
			resolved[next_miss] = true
			miss += 1
			combo = 0
		next_miss += 1


func hit(lane: int, time: float) -> String:
	expire(time)
	var nearest := -1
	var distance := GOOD_WINDOW
	for i in range(next_miss, notes.size()):
		var note := notes[i]
		if note.x - time > GOOD_WINDOW:
			break
		var error := absf(note.x - time)
		if int(note.y) == lane and not resolved.has(i) and error <= distance:
			nearest = i
			distance = error
	if nearest < 0:
		combo = 0
		return "empty"
	resolved[nearest] = true
	combo += 1
	best = maxi(best, combo)
	if distance <= PERFECT_WINDOW:
		perfect += 1
		return "perfect"
	good += 1
	return "good"


func score() -> int:
	return perfect * 100 + good * 60


func passed() -> bool:
	return score() >= notes.size() * 70
