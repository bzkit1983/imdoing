extends RefCounted
## Theme place shell + guest model ids (theme_historic / scenario 9 gate).
## Missing bake → callers fall back via Vox.has_anim / texture null checks.

const StateScript = preload("res://scripts/game_state.gd")

const FLOOR_DEFAULT := "floor_tile"
const FLOOR_HISTORIC := "floor_tile_sengoku"
const WALL_DEFAULT := "wall"
const WALL_HISTORIC := "wall_sengoku"
const THIEF_DEFAULT := "thief"
const THIEF_HISTORIC := "thief_sengoku"

const GUEST_DEFAULT := "customer"
const GUEST_HISTORIC: Array[String] = [
	"customer_sengoku_samurai",
	"customer_sengoku_civilian",
	"customer_sengoku_merchant",
]


static func uses_historic_place_shell(state: Object) -> bool:
	if state == null:
		return false
	## Interim: scenario 9 安桃山熟食測試。Later: story theme_id == theme_historic.
	return int(state.get("scenario")) == StateScript.SCENARIO_HISTORIC_COOKED


static func floor_model_id(state: Object) -> String:
	if uses_historic_place_shell(state):
		return FLOOR_HISTORIC
	return FLOOR_DEFAULT


static func wall_model_id(state: Object) -> String:
	if uses_historic_place_shell(state):
		return WALL_HISTORIC
	return WALL_DEFAULT


static func thief_model_id(state: Object) -> String:
	if uses_historic_place_shell(state):
		return THIEF_HISTORIC
	return THIEF_DEFAULT


## Random historic archetype, or modern customer. Pace mesh not used.
static func roll_guest_model_id(state: Object) -> String:
	if uses_historic_place_shell(state):
		return GUEST_HISTORIC[randi() % GUEST_HISTORIC.size()]
	return GUEST_DEFAULT


static func resolve_model_with_fallback(preferred: String, fallback: String) -> String:
	var Vox = load("res://scripts/voxel_sprite.gd")
	if preferred != "" and Vox.has_anim(preferred, "walk"):
		return preferred
	if preferred != "" and ResourceLoader.exists("res://art/sprites/%s_0.png" % preferred):
		return preferred
	return fallback
