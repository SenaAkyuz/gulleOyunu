extends Node
## Global signal hub (docs/02 §4.1). Systems never call each other directly:
## they emit here and others listen. Keep payloads small and typed.

@warning_ignore_start("unused_signal")

# --- Shot / ball ---
signal ball_fired(ball_id: String)
signal ball_impact(position: Vector3, impulse: float, material_id: String)
signal ball_expired(ball_id: String)
## First contact of a fired ball with anything (block, core, platform): starts the refire cooldown.
signal ball_hit(ball_id: String)

# --- Blocks / objective ---
signal block_damaged(block: Node3D, hp_left: float)
signal block_broken(block: Node3D, material_id: String)
signal core_dropped(core: Node3D)

# --- Level flow ---
signal level_started(level_id: String)
signal shots_changed(shots_left: int, shots_total: int)
## clear_percent (K-018): ratio of cleared block volume (or count), live estimate while settling.
signal clear_progress_changed(ratio: float, target: float)
signal referee_state_changed(state_name: String)
signal level_completed(stars: int, shots_left: int)
signal level_failed()
## Gold paid for a level (Progress): {stars, jackpot, crystal, bonus, total, first_clear}.
## Sent on the win, and again (jackpot only) if the core falls after the win.
signal level_rewarded(level_id: String, breakdown: Dictionary)

# --- Meta (Faz 2+) ---
signal currency_changed(currency: String, amount: int)
signal ball_unlocked(ball_id: String)
signal world_unlocked(world_id: String)
## Ball pieces owned changed (Inventory). count = -1 means unlimited.
signal inventory_changed(ball_id: String, count: int)

# --- Dev (debug builds) ---
## A Dev Panel slider changed a value in memory (file: rules|balls|materials, key: dotted path).
signal dev_value_changed(file: String, key: String)

@warning_ignore_restore("unused_signal")
