extends Object
## Product SemVer — keep in sync with repo root VERSION and Git tag vMAJOR.MINOR.PATCH.
## Save format uses game_state.SAVE_VERSION (integer), not this string.

const SEMVER := "1.1.0"
const TAG := "v1.1.0"

## Test-build cheats (prep money grant, etc.). Keep true for Alpha / Pages try-play.
## Official store release: set false (or delete gated UI) before shipping.
const TEST_TOOLS := true


static func test_tools_enabled() -> bool:
	return TEST_TOOLS
