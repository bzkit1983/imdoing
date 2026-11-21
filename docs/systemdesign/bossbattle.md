# 頭目戰回合（框架）

- 此檔定義**頭目戰營運日**的共用規則；各頭目玩法另開 [`bosses/`](bosses/) 專檔
- 章節節點／失敗 D→C／報酬框架見 [`storysystem.md`](storysystem.md)；任務失敗見 [`tasksystem.md`](tasksystem.md)
- 測試進場：劇本6「頭目戰」（藍本＝劇本4）；見 [`storepreparationphase.md`](storepreparationphase.md)
- 工程活線：`godot/game`（`host/boss_world.gd` 等）；正式劇情觸發／奧義解鎖表本檔不涵蓋

# 定義

- **頭目戰**＝章節主線終點（或測試劇本）的**特殊營運日**，場景仍是本店店舖設計，不是另開戰鬥場
- 目標不單純是營運指標，而是依該頭目專檔用特定方式完成條件
- 可多階段；階段之間可插入一或多段劇情演出，演出後回到頭目戰
- 通關後劇情演出 → 結算 → 回準備回合

# 日循環位置

```
準備 →（可補貨）→ 頭目進店演出 → 頭目戰階段… → 通關／失敗演出 → 結算 → 準備
```

- 準備完成後進入該營運日即為頭目日（正式路徑：章末頭目事件已掛載；測試：劇本6）
- 補貨時段規則預設與一般營運相同（頭目專檔可另說）
- 頭目日預設**計時**（標準補貨 30s＋營運 3min，見 [`storeoperationphase.md`](storeoperationphase.md)）；專檔可覆寫

# 世界覆寫（預設）

除非該頭目專檔另寫：

| 項目 | 頭目日預設 |
|------|------------|
| 普通客人 | **不生成** |
| 小偷 | **不生成** |
| 污物生成 | **關閉**（開場污物亦不種） |
| 在店對象 | 僅該頭目（加玩家／非收銀店員／傢俬） |
| 收銀店員 | **不派出**（雇員配置保留；見 [`clerksystem.md`](clerksystem.md)） |
| 場景 | 本店當日店舖設計 |

# 階段與進度 HUD

- 每個頭目自訂階段表（清單段、付款波、其他壓力等）
- 畫面**上方正中**顯示頭目戰進度條（血量計語意）：
  - 開場**全滿**
  - 每**完成一階段**扣一格／等比例
  - 任務完成時清空（0）
- 總格數＝該頭目定義的階段數（例：外星大土豪 5 清單＋3 付款＝8）

# 演出（框架）

共用最小演出契約（實作可簡化）：

1. **暫停營運時計**（世界／客人／不滿跟時計走的一併停）
2. **所有角色停步**（頭目／玩家／店員／分身等；`cutscene_freezes_actors`）
3. **ZOOM IN** 到頭目（可复用麻煩客人 focus；補貨開場可無 ZOOM）
4. 可選：一字一字大標題、劇情對話框
5. 結束 → 鏡頭還原 → **RESUME** 時計與移動

階段間、通關前、失敗時皆走此契約；台詞與次數見各頭目專檔。

**BGM：** 頭目進場時切 `BossBattle1.mp3`（`BgmBus.enter_boss`）；回準備還原（見 `bgm.md`）。

# 成功

1. 達成該頭目通關條件
2. 通關演出（專檔）
3. 可選大標題（如「任務完成」一字一字）
4. **普通結算**照算（營業額→資金等）
5. **任務／頭目獎勵另發**（大額 XP／資金／首次奧義——正式表見成長分析；測試可用占位常數）
6. 回準備；正式路徑可 `advance_story`

# 失敗（D→C）

觸發（預設，專檔可加）：

- 營運時計到點仍未通關
- 頭目不滿度達上限並離店

流程：

1. 失敗演出
2. **歸還所有未付款貨品**（對齊關店時未付款購物車退倉語意，見 [`storeoperationphase.md`](storeoperationphase.md)）
3. 回準備；可改配裝／進貨後再挑戰同一頭目節點
4. 通過前不 `advance_story`（`story_blocked`）；測試劇本6 可直接再「開始營運」重試
5. 不發頭目大額／解鎖獎

# 與現有系統

| 系統 | 關係 |
|------|------|
| [`customer.md`](customer.md)／[`elitecustomer.md`](elitecustomer.md) | 頭目可复用客人狀態機／「不主動購物」等；專檔覆寫 |
| [`cashiersystem.md`](cashiersystem.md) | 可覆寫指令次數／多波同趟付款 |
| [`storysystem.md`](storysystem.md) | 章節頭目節點、D→C、報酬框架 |
| 技能跳過收銀／店員代收 | 對頭目**預設無效**（保專檔付款設計）；專檔可放寬 |

# 專檔目錄

| 檔 | 頭目 |
|----|------|
| [`bosses/alien_tycoon.md`](bosses/alien_tycoon.md) | 外星大土豪（測試版） |

# 相關文件

- [`storeoperationphase.md`](storeoperationphase.md) — 時計／結算／退倉
- [`storepreparationphase.md`](storepreparationphase.md) — 劇本6
- [`story/progression-crossref.md`](story/progression-crossref.md) — 決策對照
