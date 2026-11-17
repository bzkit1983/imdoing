# 2026-11-18　收銀取消 Circle ＋ INT／技能重做

## 今次做過嘅嘢

### 收銀核心

1. **取消 Loading Circle**：玩家指令完成即入帳（仍須長按行動；中途放手重置指令串）。
2. **指令底數**：1–5 件 → **7**；6 件或以上 → **8**。
3. **INT 減次數**（效果頂 INT 50；配點可更高但本系統效果封頂 50）：
   - ≥20 → −2；≥30 → 再 −1；≥40 → 再 −1；≥50 → 再 −1（累計最多 −5）
   - 最終次數 = `max(2, 底數 − INT減)`
4. **親收營業額**：`payout × (1 + INT％ + 人肉％) × (Perfect 則 ×1.05)`
   - INT 階梯：10→0%、20→5%、30→10%、40→15%、50→20%
5. 店員／影分身／Dark Side 臨時收銀：**就緒即收**（無箭頭、無玩家 Circle）。
6. Self Checkout 每客秒數**不變**。

### 技能重做（舊 Circle％ 廢除）

| 程式 id | 中文名 | 新動詞 |
| --- | --- | --- |
| `checkout_rush` | 人肉數錢機 | 期間加錢 |
| `checkout_speed` | 收銀速度增加 | Perfect 連鎖減指令／只顯示餘箭 |
| `senior_cashier` | 資深收銀員 | 期間雙人結算 |

三招準備頁皆可選 LV1／2／3；沒選預設 LV3。

### 後續修正

1. **資深雙收 bug**：第二人入帳後再入隊再付 → 收第一人前記住 `queue[1]`（只收 `QUEUE`／`PAYING`）；`finish_paid` 清 `register`／`checkout_seq`，確保離店、唔再 enqueue。
2. **預填顯示**：Perfect 後下一客**切走**頭 N 格，頭上只顯示餘下箭。
3. **撳錯還原**：失敗時還原完整指令串由頭打；本客唔算 Perfect；連鎖中斷（下一客回復滿額指令，直至再次 Perfect）。

### 主要觸及檔案

- 程式：`tuning.gd`、`player.gd`、`skills.gd`、`skill_caster.gd`、`customer.gd`、`clerk.gd`、`shadow_clone.gd`、locale CSV
- 設計（中文）：`cashiersystem.md`、`playerstats.md`、`playeraction.md`、`playeractiveskills.md`、`playerpassiveskills.md`、`clerksystem.md`、`shadowclone.md`、`ratingsystem.md`、`soundeffects.md`、`playerskills.md`

---

## 新技能效果說明

### 人肉數錢機（`checkout_rush`）

- **類型**：主動技能，COST 1
- **說明**：使出後一段時間內**親收營業額**短暫上升。與 INT 營業額％**相加**，再 × Perfect 1.05。不改 INT、不改指令次數、無 Loading Circle。
- **效果**：
  - LV1：親收營業額 +15%，維持 20 秒
  - LV2：親收營業額 +25%，維持 20 秒
  - LV3：親收營業額 +40%，維持 20 秒
- **冷卻**：10 秒（INT 10 表列；實際 CD 見 `playerstats.md`）

### 收銀速度增加（`checkout_speed`）

- **類型**：被動技能，COST 1
- **說明**：**Perfect** 親收成功後，下一客開場從指令串**切走**頭 N 格（頭上只顯示餘下要輸入的箭；切走的不算錯誤）。打完餘下且無錯仍可再 Perfect（連鎖繼續）。**一旦撳錯**：即還原完整指令串由頭打，本客不算 Perfect，連鎖中斷（之後客人回復滿額指令，直至再次 Perfect）。非 Perfect 入帳不給預填；未消耗預填最多一層。不改 INT、無 Circle。影分身無箭頭，**不分給分身**。
- **效果**：
  - LV1：下一客略過頭 **1** 格（只顯示餘下）
  - LV2：下一客略過頭 **1** 格（只顯示餘下）
  - LV3：下一客略過頭 **2** 格（只顯示餘下）

### 資深收銀員（`senior_cashier`）

- **類型**：主動技能，COST 2
- **說明**：使出後一段時間內，玩家**每成功親收一人**後，若該機台佇列**下一位**已是 `QUEUE`／`PAYING`（走位 `TO_CASHIER` 不算），依 LV 機率一併入帳並**離店**（略過其指令；入帳後不得再入隊再付）。只影響玩家親收。順收第二人可套 INT／人肉營業額％，**不套** Perfect×1.05、**不算**完美收銀評價；同一次最多多收一人。不改指令次數。
- **效果**：
  - LV1：雙收機率 **40%**，維持 **15** 秒
  - LV2：雙收機率 **70%**，維持 **30** 秒
  - LV3：雙收機率 **100%**，維持 **45** 秒
- **冷卻**：15 秒（INT 10 表列；實際 CD 見 `playerstats.md`）

---

## 設計對照

權威條文以 `docs/systemdesign/` 為準：

- `cashiersystem.md`
- `playerstats.md`
- `playeractiveskills.md`
- `playerpassiveskills.md`
