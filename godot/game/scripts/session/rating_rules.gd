extends RefCounted
## Ops / shop rating formulas (docs/systemdesign/ratingsystem.md).

const OPS_START := 50
const HISTORY_MAX := 30

const P1A_PERFECT_CHECKOUT := 3
const P1B_CHECKOUT := 1
const P2_ELITE_CHECKOUT := 10
const P3_CATCH := 5
const P4_CLEAN := 1
const P5_COMBO := 1
const N1_ANGRY := -5
const N2_STOLEN_PIECE := -2
const N3_THIEF_ESCAPE := -3
const N4_WRONG_DELIVER := -1
const N5_DASH_GUEST := -1
const N6_FIGHT_FAIL := -2

const DIFF_EASY := "easy"
const DIFF_NORMAL := "normal"
const DIFF_HARD := "hard"
const DIFF_ORDER: Array[String] = [DIFF_EASY, DIFF_NORMAL, DIFF_HARD]


static func grade_for_ops(ops: int) -> int:
	if ops < 0:
		return -3
	if ops <= 20:
		return -2
	if ops <= 40:
		return -1
	if ops <= 60:
		return 0
	if ops <= 80:
		return 1
	if ops <= 100:
		return 2
	return 3


static func grade_label_key(grade: int) -> String:
	match clampi(grade, -3, 3):
		-3:
			return "rating.grade.m3"
		-2:
			return "rating.grade.m2"
		-1:
			return "rating.grade.m1"
		0:
			return "rating.grade.0"
		1:
			return "rating.grade.p1"
		2:
			return "rating.grade.p2"
		_:
			return "rating.grade.p3"


static func checkout_delta(from_elite: bool, perfect: bool) -> int:
	if from_elite:
		return P2_ELITE_CHECKOUT
	return P1A_PERFECT_CHECKOUT if perfect else P1B_CHECKOUT


static func normalize_difficulty(raw: String) -> String:
	var d := String(raw).strip_edges().to_lower()
	if d == DIFF_EASY or d == DIFF_HARD:
		return d
	return DIFF_NORMAL


static func nudge_difficulty(current: String, toward_harder: bool) -> String:
	var cur := normalize_difficulty(current)
	var i := DIFF_ORDER.find(cur)
	if i < 0:
		i = 1
	if toward_harder:
		i = mini(i + 1, DIFF_ORDER.size() - 1)
	else:
		i = maxi(i - 1, 0)
	return DIFF_ORDER[i]


## Returns "down", "up", or "" if no suggestion.
static func difficulty_suggestion(history: Array) -> String:
	if history.size() < 3:
		return ""
	var a := int(history[history.size() - 3])
	var b := int(history[history.size() - 2])
	var c := int(history[history.size() - 1])
	if a <= -1 and b <= -1 and c <= -1:
		return "down"
	if a >= 1 and b >= 1 and c >= 1:
		return "up"
	return ""


static func streak_key(history: Array) -> String:
	if history.size() < 3:
		return ""
	return "%d,%d,%d" % [
		int(history[history.size() - 3]),
		int(history[history.size() - 2]),
		int(history[history.size() - 1]),
	]
