---
name: pause-ui-chrome
description: >-
  ImDoing Pause UI Chrome — Animal Crossing cozy warm dual-layer cream panel,
  full-capsule 1.5D bevel buttons, gold fill focus, sticker badges. Use when
  generating pause menu frames/buttons/badges asset packs for Gemini, or when
  the user mentions cozy Pause UI / 動森風 pause chrome.
---

# Pause UI chrome（動森暖系 Cozy → 素材包）

**Canonical body for Gemini (self-contained — paste the whole file):**  
[`imdoing-pause-ui-chrome.md`](imdoing-pause-ui-chrome.md)

## When to use

- User wants Pause menu **frames / buttons / badges** asset pack
- User will paste a skill into **Gemini** (or another image model)
- Visual direction is **動森暖系 Cozy**（奶油白＋羊皮紙雙層卡、全膠囊、1.5D 底厚邊、Focus 整顆 `#FFD43B`）

## Rules

1. Prefer the full markdown above; it embeds all hex tokens and English prompts — **do not** tell Gemini to read repo paths.
2. Existing in-game Pause/HUD/Prep visuals may be placeholders; this skill defines the **target playable** Pause chrome.
3. Assets: transparent PNG, **no baked player-facing text**; runtime copy uses Cocoa Ink `#5C4938` via Loc／Noto.
4. Player-facing strings still go through `i18n-content` if you wire labels in engine.
5. No pure black strokes; no gaussian drop shadows; focus = filled gold, not a thin ring.
6. **Type sizes／spacing:** follow [`docs/systemdesign/uitypography.md`](../../../docs/systemdesign/uitypography.md) — do not redefine the scale in the Gemini pack.

## Workflow

1. Open [`imdoing-pause-ui-chrome.md`](imdoing-pause-ui-chrome.md).
2. Paste into Gemini System／Gem／chat.
3. Run the「一次出成包」block or per-file English prompts.
4. Import PNGs into Godot (`NinePatchRect`／`StyleBoxTexture`／Theme); do not change pause behavior contracts unless asked.
