extends RefCounted

enum Hazard { HIDDEN, COLLAPSE, FAKE }

## Every section ends in a dash gap. The next section starts on solid pavement.
static func generate(seed_value: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var hazards := [Hazard.HIDDEN, Hazard.COLLAPSE, Hazard.FAKE, Hazard.HIDDEN, Hazard.COLLAPSE, Hazard.FAKE]
	var patrols := [true, false, true, false, true, false]
	for i in range(hazards.size() - 1, 0, -1):
		var hazard_pick := random.randi_range(0, i)
		var hazard: int = hazards[i]
		hazards[i] = hazards[hazard_pick]
		hazards[hazard_pick] = hazard
		var patrol_pick := random.randi_range(0, i)
		var patrol: bool = patrols[i]
		patrols[i] = patrols[patrol_pick]
		patrols[patrol_pick] = patrol
	var sections: Array[Dictionary] = []
	var x := 0
	var y := 127
	for i in hazards.size():
		var edge := x + random.randi_range(274, 292)
		var landing := edge + random.randi_range(100, 108)
		sections.append({
			"start": x,
			"ground": y,
			"edge": edge,
			"landing": landing,
			"hazard": hazards[i],
			"hazard_x": x + random.randi_range(66, 79),
			"enemy_x": x + random.randi_range(181, 204),
			"patrol": patrols[i],
		})
		x = landing
		y = clampi(y + 5 * random.randi_range(-2, 2), 107, 143)
	var trapped_gaps := [true, true, true, true, false, false]
	for i in range(trapped_gaps.size() - 1, 0, -1):
		var pick := random.randi_range(0, i)
		var trapped: bool = trapped_gaps[i]
		trapped_gaps[i] = trapped_gaps[pick]
		trapped_gaps[pick] = trapped
	for i in sections.size():
		sections[i]["gap_brick"] = trapped_gaps[i]
		sections[i]["solid_step"] = hazards[i] == Hazard.FAKE and random.randi_range(0, 1) == 1
	return {"sections": sections, "finish_start": x, "finish_ground": y}
