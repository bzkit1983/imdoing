extends RefCounted
## Dark Side: who can be drafted, which registers are empty, who stands where.
## Effect timers live on each guest. This script does not keep a shared 30s window.

const Tuning = preload("res://scripts/tuning.gd")
const Customer = preload("res://scripts/customer.gd")

const DURATION := 30.0


static func draft_count(level: int) -> int:
	return clampi(level, 1, 3)


static func roll_cashier() -> bool:
	return randf() < 0.5


## Shopping guests (enter / seek / linger / think) and queued guests.
## Not paying, elites, thieves, leaving, list-done walkers, raiders, or temps.
## `locked` is the guest the player is checking out right now.
static func eligible(c, locked) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if locked != null and c == locked:
		return false
	if bool(c.get("is_thief")) or bool(c.get("is_elite")) or bool(c.get("temp_clerk")):
		return false
	var st := int(c.get("state"))
	return (
		st == Customer.State.ENTER
		or st == Customer.State.SEEK
		or st == Customer.State.LINGER
		or st == Customer.State.THINK
		or st == Customer.State.QUEUE
	)


## A register is empty only when no hired cashier is bound, no temp cashier
## holds it, and the player is not behind it (or already typing on it).
static func open_registers(
	registers: Array,
	hired_bound: Array,
	temp_bound: Array,
	player_pos: Vector2,
	lock_target,
) -> Array:
	var open: Array = []
	for reg in registers:
		if reg == null or not is_instance_valid(reg):
			continue
		if reg in hired_bound or reg in temp_bound:
			continue
		var back: Vector2 = reg.call("back_position")
		if player_blocks(player_pos, back, lock_target == reg):
			continue
		open.append(reg)
	return open


static func player_blocks(player_pos: Vector2, back: Vector2, locked: bool) -> bool:
	if locked:
		return true
	return player_pos.distance_squared_to(back) <= Tuning.INTERACT_RANGE_SQ


## Among people who rolled cashier, the nearer one takes each empty register.
## Same distance picks at random. Everyone else is restock until they revert.
static func plan(drafted: Array, cashier_rolls: Array, empties: Array) -> Dictionary:
	var assigned := _assign(cashier_rolls, empties)
	var out := {}
	for c in drafted:
		if assigned.has(c):
			out[c] = {"role": "cashier", "register": assigned[c]}
		else:
			out[c] = {"role": "restock", "register": null}
	return out


static func _assign(rolls: Array, empties: Array) -> Dictionary:
	var left: Array = []
	for c in rolls:
		left.append(c)
	var out := {}
	for reg in empties:
		if left.is_empty() or reg == null:
			continue
		var back: Vector2 = reg.call("back_position")
		var best: Array = []
		var best_d := INF
		for c in left:
			var d := (c as Node2D).global_position.distance_squared_to(back)
			if best.is_empty() or d < best_d - 0.01:
				best_d = d
				best = [c]
			elif absf(d - best_d) <= 0.01:
				best.append(c)
		if best.is_empty():
			continue
		var pick = best[randi() % best.size()]
		out[pick] = reg
		left.erase(pick)
	return out
