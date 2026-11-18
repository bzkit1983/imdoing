extends RefCounted
## Ops-round consumable catalog (道具). Design: docs/systemdesign/opsitems.md

const SLOT_COUNT := 4
## Test build: all four bag slots unlocked.
const UNLOCKED_SLOTS := 4

const COMFORT_BOMB := "comfort_bomb"
const CLEAN_BOMB := "clean_bomb"
const VILLAIN_BOMB := "villain_bomb"

const IDS: Array[String] = [COMFORT_BOMB, CLEAN_BOMB, VILLAIN_BOMB]

## Open-phase baseline: about 4–6 spawns per open window (~180s).
const SPAWN_FIRST_SEC := 8.0
const SPAWN_EVERY_MIN := 30.0
const SPAWN_EVERY_MAX := 45.0
const SPAWN_CAP := 4

const PICKUP_SIZE := Vector2(36, 36)


static func is_known(id: String) -> bool:
	return id in IDS


static func display_name(id: String) -> String:
	if not is_known(id):
		return id
	return Loc.t("ops_item.%s.name" % id)


static func blurb(id: String) -> String:
	if not is_known(id):
		return ""
	return Loc.t("ops_item.%s.blurb" % id)


static func random_id() -> String:
	return IDS[randi() % IDS.size()]


static func empty_bag() -> Array[String]:
	var bag: Array[String] = []
	bag.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		bag[i] = ""
	return bag


static func unlocked_count() -> int:
	return clampi(UNLOCKED_SLOTS, 0, SLOT_COUNT)


static func first_empty_slot(bag: Array) -> int:
	var n := unlocked_count()
	for i in n:
		if i >= bag.size():
			return i
		if String(bag[i]) == "":
			return i
	return -1


static func slot_item(bag: Array, slot: int) -> String:
	if slot < 0 or slot >= unlocked_count():
		return ""
	if slot >= bag.size():
		return ""
	return String(bag[slot])
