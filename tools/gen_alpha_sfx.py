#!/usr/bin/env python3
"""Generate Alpha placeholder SFX WAVs from docs/systemdesign/soundeffects.md IDs.

Procedural tones for try-play / wiring. Sound designers replace files later;
keep filenames stable: godot/game/audio/sfx/<id>.wav
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "game" / "audio" / "sfx"
SR = 22050


def clamp(x: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return lo if x < lo else hi if x > hi else x


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(clamp(s) * 32767.0)
            frames += struct.pack("<h", v)
        w.writeframes(frames)


def env_adsr(n: int, a: float, d: float, s: float, r: float) -> list[float]:
    a_n = max(1, int(a * SR))
    d_n = max(1, int(d * SR))
    r_n = max(1, int(r * SR))
    sus_n = max(0, n - a_n - d_n - r_n)
    out: list[float] = []
    for i in range(a_n):
        out.append(i / a_n)
    for i in range(d_n):
        out.append(1.0 - (1.0 - s) * (i / d_n))
    out.extend([s] * sus_n)
    for i in range(r_n):
        out.append(s * (1.0 - i / r_n))
    if len(out) < n:
        out.extend([0.0] * (n - len(out)))
    return out[:n]


def noise(n: int, seed: int = 1) -> list[float]:
    # LCG pseudo-noise, deterministic
    x = seed & 0xFFFFFFFF
    out: list[float] = []
    for _ in range(n):
        x = (1664525 * x + 1013904223) & 0xFFFFFFFF
        out.append((x / 0xFFFFFFFF) * 2.0 - 1.0)
    return out


def tone(
    dur: float,
    freq: float,
    *,
    kind: str = "sine",
    vol: float = 0.55,
    a: float = 0.005,
    d: float = 0.04,
    s: float = 0.35,
    r: float = 0.08,
    slide: float = 0.0,
    noise_mix: float = 0.0,
    seed: int = 1,
) -> list[float]:
    n = max(1, int(dur * SR))
    e = env_adsr(n, a, d, s, r)
    nz = noise(n, seed) if noise_mix > 0.0 else [0.0] * n
    out: list[float] = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + slide * (t / max(dur, 1e-6)))
        phase += 2.0 * math.pi * f / SR
        if kind == "sine":
            v = math.sin(phase)
        elif kind == "square":
            v = 1.0 if math.sin(phase) >= 0.0 else -1.0
        elif kind == "tri":
            v = 2.0 * abs(2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0) - 1.0
        elif kind == "saw":
            v = 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
        else:
            v = math.sin(phase)
        v = v * (1.0 - noise_mix) + nz[i] * noise_mix
        out.append(v * e[i] * vol)
    return out


def mix(*parts: list[float], gap: float = 0.0) -> list[float]:
    out: list[float] = []
    g = [0.0] * int(gap * SR) if gap > 0 else []
    for i, p in enumerate(parts):
        if i:
            out.extend(g)
        out.extend(p)
    # soft peak normalize
    peak = max((abs(x) for x in out), default=1.0)
    if peak > 0.95:
        out = [x * (0.95 / peak) for x in out]
    return out


def overlay(*layers: list[float]) -> list[float]:
    n = max((len(l) for l in layers), default=0)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    peak = max((abs(x) for x in out), default=1.0)
    if peak > 0.95:
        out = [x * (0.95 / peak) for x in out]
    return out


# id -> synth callable
RECIPES: dict[str, callable] = {}


def R(id_: str, fn):
    RECIPES[id_] = fn
    return fn


# --- movement ---
R("sfx_move_foot_walk", lambda: tone(0.08, 180, kind="noise" if False else "sine", vol=0.28, a=0.002, d=0.02, s=0.15, r=0.04, noise_mix=0.55, seed=11))
R("sfx_move_foot_run", lambda: tone(0.06, 220, kind="sine", vol=0.34, a=0.001, d=0.015, s=0.12, r=0.03, noise_mix=0.65, seed=12))
R("sfx_move_dash", lambda: overlay(
    tone(0.18, 420, kind="saw", vol=0.35, a=0.001, d=0.05, s=0.2, r=0.1, slide=-0.55, seed=13),
    tone(0.14, 900, kind="sine", vol=0.22, a=0.001, d=0.04, s=0.1, r=0.08, slide=-0.7, seed=14),
))
R("sfx_move_stamina_empty", lambda: tone(0.16, 140, kind="square", vol=0.3, a=0.002, d=0.05, s=0.2, r=0.08, slide=-0.3, seed=15))
R("sfx_move_overcarry", lambda: tone(0.22, 90, kind="saw", vol=0.22, a=0.01, d=0.06, s=0.35, r=0.1, noise_mix=0.25, seed=16))
R("sfx_move_crowd", lambda: mix(
    tone(0.08, 300, kind="sine", vol=0.2, seed=17),
    tone(0.1, 260, kind="tri", vol=0.18, seed=18),
    gap=0.04,
))
R("sfx_move_slip", lambda: overlay(
    tone(0.22, 600, kind="saw", vol=0.32, a=0.001, d=0.08, s=0.15, r=0.12, slide=-0.8, noise_mix=0.4, seed=19),
    tone(0.12, 120, kind="sine", vol=0.4, a=0.001, d=0.04, s=0.2, r=0.06, seed=20),
))
R("sfx_move_stun", lambda: tone(0.28, 70, kind="sine", vol=0.45, a=0.002, d=0.1, s=0.25, r=0.14, noise_mix=0.2, seed=21))
R("sfx_move_dirt_step", lambda: tone(0.1, 160, kind="sine", vol=0.22, a=0.002, d=0.03, s=0.1, r=0.05, noise_mix=0.7, seed=22))

# --- box / restock ---
R("sfx_box_pull", lambda: overlay(
    tone(0.14, 180, kind="tri", vol=0.4, a=0.002, d=0.05, s=0.2, r=0.07, slide=0.35, seed=30),
    tone(0.1, 90, kind="sine", vol=0.25, seed=31),
))
R("sfx_box_pull_fail", lambda: tone(0.12, 110, kind="square", vol=0.28, a=0.002, d=0.04, s=0.15, r=0.06, seed=32))
R("sfx_box_sku_open", lambda: tone(0.1, 520, kind="sine", vol=0.3, a=0.002, d=0.03, s=0.2, r=0.05, slide=0.2, seed=33))
R("sfx_box_sku_move", lambda: tone(0.05, 700, kind="sine", vol=0.22, a=0.001, d=0.015, s=0.1, r=0.025, seed=34))
R("sfx_box_sku_confirm", lambda: tone(0.1, 660, kind="sine", vol=0.32, a=0.002, d=0.03, s=0.2, r=0.05, seed=35))
R("sfx_box_sku_cancel", lambda: tone(0.09, 320, kind="sine", vol=0.25, a=0.002, d=0.03, s=0.15, r=0.05, slide=-0.25, seed=36))
R("sfx_shelf_stock_loop", lambda: tone(0.16, 240, kind="tri", vol=0.18, a=0.01, d=0.04, s=0.4, r=0.06, noise_mix=0.35, seed=37))
R("sfx_shelf_stock_done", lambda: mix(
    tone(0.08, 400, kind="tri", vol=0.35, seed=38),
    tone(0.12, 620, kind="sine", vol=0.3, slide=0.15, seed=39),
    gap=0.02,
))
R("sfx_shelf_stock_blocked", lambda: tone(0.14, 180, kind="square", vol=0.32, a=0.002, d=0.05, s=0.2, r=0.07, seed=40))
R("sfx_shelf_stock_instant", lambda: mix(
    tone(0.06, 480, kind="tri", vol=0.35, seed=41),
    tone(0.1, 780, kind="sine", vol=0.32, slide=0.25, seed=42),
    gap=0.015,
))
R("sfx_box_drop_aim", lambda: tone(0.08, 880, kind="sine", vol=0.25, a=0.001, d=0.02, s=0.15, r=0.04, seed=43))
R("sfx_box_toss", lambda: overlay(
    tone(0.16, 380, kind="saw", vol=0.3, a=0.001, d=0.05, s=0.15, r=0.08, slide=-0.45, seed=44),
    tone(0.1, 700, kind="sine", vol=0.18, slide=-0.5, seed=45),
))
R("sfx_box_drop_feet", lambda: tone(0.12, 140, kind="tri", vol=0.4, a=0.001, d=0.04, s=0.15, r=0.06, noise_mix=0.25, seed=46))
R("sfx_box_land", lambda: overlay(
    tone(0.14, 120, kind="sine", vol=0.42, a=0.001, d=0.05, s=0.15, r=0.07, noise_mix=0.3, seed=47),
    tone(0.08, 60, kind="sine", vol=0.3, seed=48),
))
R("sfx_box_shelf_toss", lambda: mix(
    tone(0.1, 130, kind="tri", vol=0.38, noise_mix=0.25, seed=49),
    tone(0.12, 540, kind="sine", vol=0.28, slide=0.2, seed=50),
    gap=0.03,
))
R("sfx_box_pickup_floor", lambda: tone(0.12, 200, kind="tri", vol=0.35, a=0.002, d=0.04, s=0.2, r=0.06, slide=0.25, seed=51))

# --- checkout ---
R("sfx_checkout_enter", lambda: tone(0.14, 480, kind="sine", vol=0.3, a=0.005, d=0.04, s=0.25, r=0.07, seed=60))
R("sfx_checkout_dir_ok", lambda: tone(0.06, 760, kind="sine", vol=0.28, a=0.001, d=0.02, s=0.15, r=0.03, seed=61))
R("sfx_checkout_dir_fail", lambda: mix(
    tone(0.08, 200, kind="square", vol=0.32, seed=62),
    tone(0.08, 160, kind="square", vol=0.28, seed=63),
    gap=0.04,
))
R("sfx_checkout_seq_done", lambda: mix(
    tone(0.07, 520, kind="sine", vol=0.3, seed=64),
    tone(0.1, 780, kind="sine", vol=0.28, seed=65),
    gap=0.03,
))
R("sfx_checkout_circle_done", lambda: overlay(
    tone(0.18, 880, kind="sine", vol=0.35, a=0.002, d=0.05, s=0.25, r=0.1, seed=66),
    tone(0.12, 440, kind="tri", vol=0.22, seed=67),
))
R("sfx_checkout_cash_pop", lambda: mix(
    tone(0.06, 1200, kind="sine", vol=0.28, seed=68),
    tone(0.08, 1600, kind="sine", vol=0.22, seed=69),
    gap=0.02,
))
R("sfx_checkout_release_reset", lambda: tone(0.08, 300, kind="sine", vol=0.22, a=0.002, d=0.03, s=0.1, r=0.04, slide=-0.2, seed=70))
R("sfx_checkout_clerk", lambda: tone(0.16, 820, kind="sine", vol=0.22, a=0.003, d=0.05, s=0.2, r=0.08, seed=71))

# --- clean ---
R("sfx_clean_start", lambda: tone(0.1, 340, kind="tri", vol=0.28, a=0.003, d=0.03, s=0.2, r=0.05, seed=80))
R("sfx_clean_scrub", lambda: tone(0.07, 280, kind="sine", vol=0.22, a=0.001, d=0.02, s=0.15, r=0.03, noise_mix=0.55, seed=81))
R("sfx_clean_done", lambda: mix(
    tone(0.08, 600, kind="sine", vol=0.3, seed=82),
    tone(0.12, 960, kind="sine", vol=0.28, slide=0.2, seed=83),
    gap=0.02,
))
R("sfx_clean_cancel", lambda: tone(0.08, 220, kind="sine", vol=0.2, slide=-0.2, seed=84))

# --- fight / thief ---
R("sfx_fight_grab", lambda: tone(0.14, 160, kind="saw", vol=0.4, a=0.002, d=0.05, s=0.25, r=0.07, noise_mix=0.2, seed=90))
R("sfx_fight_hit", lambda: overlay(
    tone(0.09, 220, kind="square", vol=0.35, a=0.001, d=0.03, s=0.15, r=0.04, seed=91),
    tone(0.07, 90, kind="sine", vol=0.3, seed=92),
))
R("sfx_fight_fail", lambda: overlay(
    tone(0.2, 100, kind="saw", vol=0.4, a=0.001, d=0.08, s=0.2, r=0.1, noise_mix=0.3, seed=93),
    tone(0.16, 60, kind="sine", vol=0.35, seed=94),
))
R("sfx_ko_screen", lambda: overlay(
    tone(0.28, 80, kind="sine", vol=0.5, a=0.001, d=0.1, s=0.3, r=0.14, seed=95),
    tone(0.2, 240, kind="saw", vol=0.28, slide=-0.4, seed=96),
    tone(0.12, 1200, kind="sine", vol=0.18, a=0.001, d=0.04, s=0.1, r=0.06, seed=97),
))
R("sfx_ko_guest_dash", lambda: overlay(
    tone(0.22, 100, kind="sine", vol=0.4, a=0.001, d=0.08, s=0.25, r=0.1, seed=98),
    tone(0.14, 300, kind="tri", vol=0.22, slide=-0.3, seed=99),
))
R("sfx_thief_dash_out", lambda: overlay(
    tone(0.2, 500, kind="saw", vol=0.32, a=0.001, d=0.06, s=0.15, r=0.1, slide=-0.65, seed=100),
    tone(0.14, 900, kind="sine", vol=0.2, slide=-0.7, seed=101),
))
R("sfx_loot_scatter", lambda: mix(
    tone(0.08, 140, kind="tri", vol=0.3, noise_mix=0.3, seed=102),
    tone(0.08, 170, kind="tri", vol=0.28, noise_mix=0.3, seed=103),
    tone(0.1, 120, kind="tri", vol=0.3, noise_mix=0.35, seed=104),
    gap=0.03,
))
R("sfx_loot_inplace", lambda: tone(0.16, 110, kind="tri", vol=0.4, a=0.001, d=0.06, s=0.2, r=0.08, noise_mix=0.35, seed=105))
R("sfx_box_hit_thief", lambda: overlay(
    tone(0.12, 150, kind="square", vol=0.38, a=0.001, d=0.04, s=0.15, r=0.06, seed=106),
    tone(0.1, 80, kind="sine", vol=0.3, seed=107),
))
R("sfx_box_hit_guest_ok", lambda: mix(
    tone(0.08, 520, kind="sine", vol=0.28, seed=108),
    tone(0.1, 700, kind="sine", vol=0.26, seed=109),
    gap=0.02,
))
R("sfx_box_hit_guest_reject", lambda: tone(0.14, 180, kind="square", vol=0.3, a=0.002, d=0.05, s=0.2, r=0.07, seed=110))
R("sfx_thief_escape", lambda: mix(
    tone(0.12, 880, kind="square", vol=0.32, seed=111),
    tone(0.12, 660, kind="square", vol=0.3, seed=112),
    tone(0.18, 440, kind="saw", vol=0.28, seed=113),
    gap=0.05,
))
R("sfx_thief_spawn", lambda: tone(0.18, 200, kind="tri", vol=0.22, a=0.01, d=0.06, s=0.25, r=0.08, slide=-0.15, noise_mix=0.15, seed=114))

# --- guests ---
R("sfx_guest_enter", lambda: mix(
    tone(0.1, 880, kind="sine", vol=0.2, seed=120),
    tone(0.14, 1100, kind="sine", vol=0.18, seed=121),
    gap=0.04,
))
R("sfx_guest_take", lambda: tone(0.1, 300, kind="tri", vol=0.22, a=0.002, d=0.03, s=0.15, r=0.05, seed=122))
R("sfx_guest_think", lambda: tone(0.16, 420, kind="sine", vol=0.18, a=0.01, d=0.05, s=0.25, r=0.08, slide=0.1, seed=123))
R("sfx_guest_queue", lambda: tone(0.1, 180, kind="sine", vol=0.18, a=0.005, d=0.03, s=0.15, r=0.05, seed=124))
R("sfx_guest_angry_leave", lambda: tone(0.18, 160, kind="saw", vol=0.32, a=0.002, d=0.06, s=0.2, r=0.08, slide=-0.25, seed=125))
R("sfx_guest_paid_leave", lambda: tone(0.12, 640, kind="sine", vol=0.22, a=0.003, d=0.04, s=0.2, r=0.06, seed=126))
R("sfx_guest_dash_land", lambda: tone(0.14, 100, kind="sine", vol=0.35, a=0.001, d=0.05, s=0.15, r=0.07, noise_mix=0.25, seed=127))

# --- skills / ult ---
R("sfx_skill_cast", lambda: overlay(
    tone(0.16, 480, kind="sine", vol=0.32, a=0.002, d=0.05, s=0.2, r=0.08, slide=0.35, seed=130),
    tone(0.12, 720, kind="tri", vol=0.2, slide=0.25, seed=131),
))
R("sfx_skill_menu_open", lambda: tone(0.1, 560, kind="sine", vol=0.28, a=0.003, d=0.03, s=0.2, r=0.05, seed=132))
R("sfx_skill_menu_move", lambda: tone(0.05, 680, kind="sine", vol=0.2, a=0.001, d=0.015, s=0.1, r=0.025, seed=133))
R("sfx_skill_menu_cancel", lambda: tone(0.09, 340, kind="sine", vol=0.22, slide=-0.25, seed=134))
R("sfx_skill_cd_deny", lambda: tone(0.12, 150, kind="square", vol=0.28, a=0.002, d=0.04, s=0.15, r=0.06, seed=135))
R("sfx_ult_prep", lambda: tone(0.28, 90, kind="saw", vol=0.3, a=0.02, d=0.08, s=0.45, r=0.1, slide=0.15, seed=136))
R("sfx_ult_dir_ok", lambda: tone(0.07, 520, kind="sine", vol=0.28, a=0.001, d=0.02, s=0.15, r=0.035, seed=137))
R("sfx_ult_dir_fail", lambda: tone(0.12, 170, kind="square", vol=0.3, a=0.002, d=0.04, s=0.15, r=0.06, seed=138))
R("sfx_ult_cancel", lambda: tone(0.14, 200, kind="sine", vol=0.22, a=0.005, d=0.05, s=0.15, r=0.07, slide=-0.4, seed=139))
R("sfx_ult_the_world", lambda: overlay(
    tone(0.35, 60, kind="sine", vol=0.45, a=0.01, d=0.12, s=0.35, r=0.15, seed=140),
    tone(0.25, 240, kind="tri", vol=0.25, slide=-0.3, seed=141),
    tone(0.15, 1400, kind="sine", vol=0.15, a=0.001, d=0.05, s=0.1, r=0.08, seed=142),
))
R("sfx_ult_the_world_end", lambda: tone(0.22, 180, kind="sine", vol=0.28, a=0.01, d=0.08, s=0.25, r=0.1, slide=0.4, seed=143))
R("sfx_ult_yes_my_lord", lambda: mix(
    tone(0.1, 400, kind="saw", vol=0.3, seed=144),
    tone(0.12, 520, kind="saw", vol=0.28, seed=145),
    tone(0.16, 660, kind="tri", vol=0.26, seed=146),
    gap=0.03,
))
R("sfx_ult_fundraise", lambda: mix(
    tone(0.08, 900, kind="sine", vol=0.28, seed=147),
    tone(0.08, 1100, kind="sine", vol=0.26, seed=148),
    tone(0.12, 1300, kind="sine", vol=0.24, seed=149),
    gap=0.025,
))
R("sfx_skill_soothe", lambda: tone(0.22, 380, kind="sine", vol=0.26, a=0.02, d=0.08, s=0.35, r=0.1, slide=0.15, seed=150))

# --- clerks ---
R("sfx_clerk_pull", lambda: tone(0.12, 170, kind="tri", vol=0.22, a=0.002, d=0.04, s=0.15, r=0.05, slide=0.2, seed=160))
R("sfx_clerk_stock", lambda: tone(0.12, 480, kind="sine", vol=0.2, a=0.003, d=0.04, s=0.15, r=0.06, seed=161))

# --- phases ---
R("sfx_phase_restock", lambda: mix(
    tone(0.12, 440, kind="tri", vol=0.3, seed=170),
    tone(0.14, 554, kind="tri", vol=0.28, seed=171),
    gap=0.04,
))
R("sfx_phase_open", lambda: mix(
    tone(0.12, 784, kind="sine", vol=0.28, seed=172),
    tone(0.16, 988, kind="sine", vol=0.26, seed=173),
    gap=0.05,
))
R("sfx_phase_close", lambda: mix(
    tone(0.14, 392, kind="sine", vol=0.3, seed=174),
    tone(0.18, 330, kind="sine", vol=0.28, seed=175),
    gap=0.06,
))
R("sfx_early_close_ask", lambda: tone(0.14, 500, kind="sine", vol=0.26, a=0.005, d=0.05, s=0.25, r=0.07, seed=176))
R("sfx_dirt_spawn", lambda: tone(0.1, 140, kind="sine", vol=0.15, a=0.002, d=0.03, s=0.1, r=0.05, noise_mix=0.6, seed=177))

# --- UI ---
R("sfx_ui_move", lambda: tone(0.045, 720, kind="sine", vol=0.2, a=0.001, d=0.012, s=0.1, r=0.02, seed=180))
R("sfx_ui_confirm", lambda: tone(0.09, 640, kind="sine", vol=0.28, a=0.002, d=0.03, s=0.2, r=0.04, seed=181))
R("sfx_ui_cancel", lambda: tone(0.08, 360, kind="sine", vol=0.24, a=0.002, d=0.025, s=0.15, r=0.04, slide=-0.2, seed=182))
R("sfx_ui_deny", lambda: tone(0.12, 160, kind="square", vol=0.3, a=0.002, d=0.04, s=0.15, r=0.06, seed=183))
R("sfx_ui_purchase", lambda: mix(
    tone(0.07, 980, kind="sine", vol=0.26, seed=184),
    tone(0.09, 1240, kind="sine", vol=0.22, seed=185),
    gap=0.02,
))
R("sfx_ui_place", lambda: tone(0.1, 420, kind="tri", vol=0.28, a=0.002, d=0.03, s=0.15, r=0.05, seed=186))
R("sfx_ui_pickup_item", lambda: tone(0.1, 360, kind="tri", vol=0.24, a=0.002, d=0.03, s=0.15, r=0.05, slide=0.2, seed=187))
R("sfx_ui_rotate", lambda: tone(0.08, 540, kind="sine", vol=0.22, a=0.002, d=0.025, s=0.15, r=0.04, slide=0.15, seed=188))
R("sfx_ui_pause_open", lambda: tone(0.12, 300, kind="sine", vol=0.26, a=0.005, d=0.04, s=0.2, r=0.06, seed=189))
R("sfx_ui_pause_close", lambda: tone(0.1, 420, kind="sine", vol=0.24, a=0.003, d=0.03, s=0.15, r=0.05, seed=190))
R("sfx_ui_level_up", lambda: mix(
    tone(0.08, 523, kind="sine", vol=0.28, seed=191),
    tone(0.08, 659, kind="sine", vol=0.26, seed=192),
    tone(0.14, 784, kind="sine", vol=0.28, seed=193),
    gap=0.04,
))
R("sfx_ui_test_skip", lambda: tone(0.09, 600, kind="sine", vol=0.24, a=0.002, d=0.03, s=0.15, r=0.04, seed=194))


# Fix recipes that used kind="noise" incorrectly — use noise_mix instead
def _fix_foot_walk():
    return tone(0.08, 180, kind="sine", vol=0.28, a=0.002, d=0.02, s=0.15, r=0.04, noise_mix=0.55, seed=11)


RECIPES["sfx_move_foot_walk"] = _fix_foot_walk


# Priority metadata for catalog export (matches soundeffects.md)
PRIORITY = {
    "sfx_move_dash": "P0", "sfx_move_slip": "P0",
    "sfx_box_pull": "P0", "sfx_shelf_stock_done": "P0", "sfx_shelf_stock_blocked": "P0",
    "sfx_box_toss": "P0", "sfx_box_drop_feet": "P0", "sfx_box_land": "P0",
    "sfx_box_shelf_toss": "P0", "sfx_box_pickup_floor": "P0",
    "sfx_checkout_dir_ok": "P0", "sfx_checkout_dir_fail": "P0",
    "sfx_checkout_circle_done": "P0", "sfx_checkout_cash_pop": "P0",
    "sfx_clean_scrub": "P0", "sfx_clean_done": "P0",
    "sfx_fight_grab": "P0", "sfx_fight_hit": "P0", "sfx_fight_fail": "P0",
    "sfx_ko_screen": "P0", "sfx_ko_guest_dash": "P0", "sfx_thief_dash_out": "P0",
    "sfx_thief_escape": "P0",
    "sfx_skill_cast": "P0", "sfx_ult_dir_ok": "P0", "sfx_ult_dir_fail": "P0",
    "sfx_ult_the_world": "P0", "sfx_ult_yes_my_lord": "P0", "sfx_ult_fundraise": "P0",
    "sfx_phase_close": "P0", "sfx_ui_deny": "P0",
    "sfx_move_foot_walk": "P1", "sfx_move_foot_run": "P1", "sfx_move_stun": "P1",
    "sfx_box_pull_fail": "P1", "sfx_box_sku_open": "P1", "sfx_shelf_stock_instant": "P1",
    "sfx_box_drop_aim": "P1",
    "sfx_checkout_enter": "P1", "sfx_checkout_seq_done": "P1", "sfx_checkout_clerk": "P1",
    "sfx_clean_start": "P1",
    "sfx_loot_scatter": "P1", "sfx_loot_inplace": "P1", "sfx_box_hit_thief": "P1",
    "sfx_box_hit_guest_ok": "P1", "sfx_box_hit_guest_reject": "P1",
    "sfx_guest_angry_leave": "P1", "sfx_guest_dash_land": "P1",
    "sfx_skill_menu_open": "P1", "sfx_skill_cd_deny": "P1", "sfx_ult_prep": "P1",
    "sfx_ult_the_world_end": "P1", "sfx_skill_soothe": "P1",
    "sfx_phase_restock": "P1", "sfx_phase_open": "P1", "sfx_early_close_ask": "P1",
    "sfx_ui_move": "P1", "sfx_ui_confirm": "P1", "sfx_ui_cancel": "P1",
    "sfx_ui_purchase": "P1", "sfx_ui_place": "P1", "sfx_ui_pause_open": "P1",
    "sfx_ui_pause_close": "P1", "sfx_ui_level_up": "P1",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    missing_pri = []
    for sid, fn in sorted(RECIPES.items()):
        samples = fn()
        write_wav(OUT / f"{sid}.wav", samples)
        if sid not in PRIORITY:
            missing_pri.append(sid)
            PRIORITY[sid] = "P2"
    # Write simple catalog for tools / docs
    cat = OUT.parent / "sfx_catalog.txt"
    lines = ["# id\tpriority\tpath"]
    for sid in sorted(RECIPES.keys(), key=lambda x: (PRIORITY.get(x, "P2"), x)):
        lines.append(f"{sid}\t{PRIORITY[sid]}\tres://audio/sfx/{sid}.wav")
    cat.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(RECIPES)} wavs to {OUT}")
    if missing_pri:
        print(f"Defaulted to P2: {', '.join(missing_pri)}")


if __name__ == "__main__":
    main()
