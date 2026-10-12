extends RefCounted
## Demo v0.1 hold-to-act numbers. Design locks AGI at 10; restock seconds
## at AGI 10 are a lab default until conversion tables exist.

const AGI_DEFAULT := 10
const STR := 10
const CARRY_CAP := 16
const BOX_SIZE := 4
const SHELF_CAP := 12
const WALK_SPEED := 180.0
const INTERACT_RANGE := 100.0
const FACE_DOT := 0.2

## Hold-to-fill duration for 上架 at AGI 10.
const RESTOCK_SECONDS_AT_10 := 0.9

const SKUS := ["罐頭", "零食", "杯麵"]
const SKU_COLORS := {
	"罐頭": Color("c45c26"),
	"零食": Color("e8c36a"),
	"杯麵": Color("3d7ea6"),
}


static func restock_seconds(agi: int) -> float:
	var a := maxi(1, agi)
	return RESTOCK_SECONDS_AT_10 * (10.0 / float(a))
