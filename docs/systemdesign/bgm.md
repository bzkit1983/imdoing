# 背景音樂（BGM）

- 活線：`godot/game`
- 工程：Autoload `BgmBus`（`scripts/bgm_bus.gd`）；Audio bus **Music**（`default_bus_layout.tres`）
- 素材：`audio/bgm/*.mp3`（loop）
- 設定：`user://settings.cfg` → `[audio] bgm_muted`、`bgm_volume`（與 SFX 並存；0–1、每檔 0.1）
- UI：暫停選單（`pausemenu.md`）；準備「系統工具」（`storepreparationphase.md`／prep hub）

## 曲目

| 檔名 | 用途 |
| --- | --- |
| `PrepareShop.mp3` | 準備回合 |
| `Operation1.mp3`／`Operation2.mp3` | 營運日（含 restock／open／結算畫面）隨機一首 |
| `EliteCustomer1.mp3`／`EliteCustomer2.mp3` | 麻煩客人在場時覆蓋 |
| `BossBattle1.mp3`（另有 `BossBattle2.mp3` 備用） | 頭目戰進場後覆蓋（見 `bossbattle.md`） |

## 切換規則

1. **開局／回準備**（`phase == "prep"`）→ `PrepareShop`
2. **開始營運日**（`_begin_day`）→ 當日重抽 `Operation1` 或 `Operation2`，整日記住不重抽
3. **麻煩客人公告**（`announce_elite_customer`）→ 若尚未在 elite／boss 主題，隨機抽 Elite 曲覆蓋
4. **場上最後一位 elite 離開**（`tree_exiting` 後掃描）→ 切回當日記住的 Operation 曲
5. **頭目進場**（頭目日 spawn）→ `BossBattle1` 覆蓋；頭目日內 elite 不搶曲
6. **回準備**（`_return_to_prep`）→ `PrepareShop`（清掉當日 Operation／elite／boss 狀態）

切曲約 0.4s fade。靜音時停播；解除靜音恢復當前應播曲目。本機演出；線上各端各自跟隨本地 phase／elite／boss 公告。

## 明確不做（本檔）

- 店內 Ambient／環境床、天氣層（見 `soundeffects.md`「明確不在本表」）
- 完整獨立設定頁產品殼（設定掛在暫停／系統工具）

## 相關文件

- 暫停：`pausemenu.md` · 音效：`soundeffects.md` · 麻煩客人：`elitecustomer.md`
- 回合：`storeoperationphase.md` · 準備：`storepreparationphase.md`
