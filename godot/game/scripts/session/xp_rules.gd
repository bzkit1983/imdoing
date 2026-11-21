extends RefCounted
## Product XP curve + day-settle rates (growth-character.md).
## Shared by GameState (host shop) and CharacterSheet (guest seats).

const LEVEL_CAP := 99

## Level-band proxy for chapter XP tiers until story_chapter_id exists.
## LV1–18 → prologue–ch2; 19–36 → ch3–5; 37–60 → ch6–finale; 61–99 → afterstory.


static func xp_need(target_lv: int) -> int:
	## XP to go from (target_lv - 1) to target_lv.
	if target_lv < 2 or target_lv > LEVEL_CAP:
		return 0
	var L := target_lv
	if L <= 20:
		return int(round(200.0 + float(L - 2) * (1100.0 / 18.0)))
	if L <= 40:
		return int(round(1500.0 + float(L - 21) * (1300.0 / 19.0)))
	if L <= 60:
		return int(round(2800.0 + float(L - 41) * (1700.0 / 19.0)))
	return int(round(3800.0 + float(L - 61) * (1700.0 / 38.0)))


static func xp_to_next(level: int) -> int:
	if level >= LEVEL_CAP:
		return 0
	return xp_need(level + 1)


## Returns {close, serve, elite, catch, clean} for settle / float preview.
static func rates_for_level(level: int) -> Dictionary:
	var lv := clampi(level, 1, LEVEL_CAP)
	if lv <= 18:
		return {"close": 80, "serve": 3, "elite": 12, "catch": 15, "clean": 6}
	if lv <= 36:
		return {"close": 120, "serve": 4, "elite": 15, "catch": 20, "clean": 8}
	if lv <= 60:
		return {"close": 180, "serve": 5, "elite": 20, "catch": 25, "clean": 10}
	return {"close": 220, "serve": 6, "elite": 25, "catch": 30, "clean": 12}


static func raw_xp_for_counts(
	level: int,
	served: int,
	caught: int,
	cleaned: int,
	elite_served: int = 0,
	bonus_xp: int = 0,
) -> int:
	var r := rates_for_level(level)
	return (
		int(r["close"])
		+ served * int(r["serve"])
		+ caught * int(r["catch"])
		+ cleaned * int(r["clean"])
		+ elite_served * int(r["elite"])
		+ bonus_xp
	)


## Mutates level/xp/unspent on `sheet` (GameState or CharacterSheet duck-type).
## Returns levels gained.
static func apply_level_ups(sheet: Object) -> int:
	var ups := 0
	var lv: int = int(sheet.level)
	var cur_xp: int = int(sheet.xp)
	while lv < LEVEL_CAP:
		var need := xp_need(lv + 1)
		if need <= 0 or cur_xp < need:
			break
		cur_xp -= need
		lv += 1
		sheet.unspent = int(sheet.unspent) + 5
		ups += 1
	sheet.level = lv
	sheet.xp = cur_xp
	return ups
