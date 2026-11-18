#!/usr/bin/env python3
"""Ordino Games - basit ekonomi simulasyonu.

Ortalama bir oyuncunun her dunya sonunda ne kadar altini oldugunu ve kac ozel top paketi
alabilecegini hesaplar. Varsayimlar: game_data/economy.json -> sim.
Kullanim:  python3 tools/economy_sim.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "game_data"
eco = json.loads((ROOT / "economy.json").read_text(encoding="utf-8"))
balls = json.loads((ROOT / "balls.json").read_text(encoding="utf-8"))["balls"]
worlds = json.loads((ROOT / "worlds.json").read_text(encoding="utf-8"))["worlds"]

r = eco["rewards"]
sim = eco["sim"]
star_reward = {int(k): v for k, v in r["stars"].items()}
dist = {int(k): v for k, v in sim["avg_stars_distribution"].items()}
avg_first = sum(star_reward[s] * p for s, p in dist.items())
avg_replay = sum(round(star_reward[s] * r["replay_ratio"]) * p for s, p in dist.items()) * sim["replays_per_level"]
crystal = min(sim["avg_crystals_per_level"], r["crystal_coin_cap_per_level"])
avg_stars = sum(s * p for s, p in dist.items())

unlock_world = {}
for b in balls:
    u = b["unlock"]
    if u["type"] == "level_cleared":
        unlock_world[b["id"]] = int(u["level_id"][1:3])

gold = eco["currencies"]["gold"]["start_amount"]
lo, hi = sim["target_packs_affordable_per_world"]
print(f"Ortalama yildiz/bolum: {avg_stars:.2f} | ilk gecis ort. altin: {avg_first:.1f} | tekrar: {avg_replay:.1f} | kristal: {crystal}\n")
print(f"{'Dunya':<20}{'Kazanc':>8}{'Birikim':>9}{'Ort. paket':>12}{'Alinabilir':>12}  Durum")
for w in worlds:
    idx, n = w["index"], w["level_count"]
    earned = (n - 1) * (avg_first + avg_replay + crystal)
    earned += (avg_first * r["boss_mult"]) + crystal  # boss
    earned += r["world_complete_bonus"]
    gold += earned
    available = [b for b in balls if b["id"] in unlock_world and unlock_world[b["id"]] <= idx]
    if not available:
        print(f"{w['name_tr']:<20}{earned:>8.0f}{gold:>9.0f}{'-':>12}{'-':>12}  (henuz ozel top yok)")
        continue
    avg_price = sum(b["price_gold"] for b in available) / len(available)
    affordable = earned / avg_price
    status = "OK" if lo <= affordable <= hi * 1.3 else ("COK CIMRI" if affordable < lo else "COK COMERT")
    print(f"{w['name_tr']:<20}{earned:>8.0f}{gold:>9.0f}{avg_price:>12.0f}{affordable:>12.1f}  {status}")

print("\nNot: 'Alinabilir' = o dunyada kazanilan altinla acik toplarin ortalama paket fiyatiyla kac tane alinabilir.")
print(f"Hedef aralik: {lo}-{hi} paket/dunya (economy.json -> sim.target_packs_affordable_per_world)")
