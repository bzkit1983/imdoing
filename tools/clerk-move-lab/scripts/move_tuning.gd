extends RefCounted
## Lab numbers for Demo v0.1. Design docs lock STR/AGI at 10 but do not
## publish conversion tables yet — these constants are labelled as lab defaults.

const STR := 10
const AGI := 10

## Carry cap used by the restock design (4 items per box). HTML lab used 16.
const CARRY_CAP_ITEMS := 16

const WALK_SPEED := 180.0
const RUN_SPEED_MULT := 1.75
const DASH_DISTANCE := 140.0
const DASH_TIME := 0.12
const RUN_HOLD_THRESHOLD := 0.18

const STAMINA_MAX := 100.0
const RUN_STAMINA_PER_SEC := 22.0
const DASH_STAMINA_COST := 28.0
const STAMINA_REGEN_PER_SEC := 16.0
const STAMINA_REGEN_DELAY := 0.35

const OVERWEIGHT_AT_CAP_MULT := 0.62
const OVERWEIGHT_OVER_CAP_MULT := 0.42
const DIRT_MULT := 0.55
const SPEED_MAX_MULT := 5.0
const SPEED_FLOOR := 48.0

static func agi_mult() -> float:
	return float(AGI) / 10.0


static func stamina_max() -> float:
	return STAMINA_MAX * (float(STR) / 10.0)
