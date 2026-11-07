# 外觀調整

- 此檔是角色外觀（造型＋色調）的單一真相來源
- 工程活線：`godot/game`。存檔見 `savesystem.md`；準備選單入口見 `storepreparationphase.md`；coop 訪客見 `multiplayer.md`

# 範圍（BETA）

- **入口：** 準備回合 → 角色整備 → **外觀調整**（`look` 頁）
- **可改：** 造型 ID（`skin_id`）＋色調索引（`tint` 0..3）
- **預覽：** Look 頁常駐 idle（南向 `k=0`）精靈；焦點列即時換模，改 tint 即改 `modulate`
- **不做（本輪）：** 分層換裝、商店購買、劇情／事件閘、營業中換裝、網路同步外觀、預覽旋轉／多動作

# 造型目錄

| ID | 顯示名 key | 說明 |
| --- | --- | --- |
| `player` | `skin.player` | 標準 |
| `player_alt1` | `skin.player_alt1` | 外星人 |
| `player_alt2` | `skin.player_alt2` | 維京人 |

- 目錄模組：`godot/game/scripts/session/skin_catalog.gd`
- Bake：`tools/voxel_sprites.py`（`CHAR_WAY`）、`tools/voxel_character_anims.py`（`CHARS`）、`godot/game/art/catalog.json`
- 執行期經 `Vox.animated(skin_id)`／`anim_manifest`；缺 idle／未 bake → fallback `player`

# 存檔

- **店主**（`save.json`／`GameState`）：`skin_id`、`unlocked_skins`、既有 `tint`
- **訪客槽**（`guest_slots.json`／`CharacterSheet`）：同樣三欄（coop 可各自造型）
- **`unlocked_skins`：** 字串 ID 陣列。**空陣列＝目錄內全部解放**（BETA 預設）。之後事件／商店只往表裡加 ID，Look UI 契約不變
- API：`is_skin_unlocked(id)`、`unlock_skin(id)`（空表時 `unlock_skin` 為 no-op，因已全開）
- 無效／未 bake 的 `skin_id` → `SkinCatalog.normalize` → `"player"`

# 解鎖長線（BETA 不做）

- 事件／劇情旗標／金錢購買 → `unlock_skin(id)` 或寫入 `unlocked_skins`
- 若要改為「預設只開標準」，存檔寫 `unlocked_skins: ["player"]` 即可；UI 仍讀同一目錄

# 執行期

- 開局 spawn：`demo` 用 sheet／`GameState.appearance_skin_id()` 建 `Vox.animated`
- `player._model_id`：`play_anim`／`apply` 全走此 ID；色調仍 `_appearance_tint()` → `modulate`
- 影分身：`clone_snapshot` 帶 `skin_id`；`shadow_clone` 跟 snapshot，不寫死 `player`
- 只在準備回合寫檔；營業中不換造型

# UI

- Look 頁：**列表**（已解放造型＋目前裝備標示）＋**色調循環列**＋右側／上方 **idle 預覽**
- 游標移到造型列 → 預覽切該 ID（未確認也可預覽）；確認 → 寫 `skin_id` 並存檔
- 離開頁銷毀預覽節點
- **單一入口：** 造型＋色調只在 Look 改；確認開店頁顯示外觀摘要（造型名＋色調），不再循環店主 tint（訪客 tint 仍可在確認頁微調以便雙人辨識）

# 非目標

分層換裝、營業中換裝、網路同步、預覽內旋轉／多動作、獨立外觀場景。
