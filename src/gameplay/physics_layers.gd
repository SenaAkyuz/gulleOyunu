class_name PhysicsLayers
extends RefCounted
## Collision layer bit values (engine plumbing, not game rules). Layer N = bit 1 << (N-1).

const PLATFORM: int = 1 << 0  # layer 1
const BLOCK: int = 1 << 1     # layer 2
const CORE: int = 1 << 2      # layer 3
const BALL: int = 1 << 3      # layer 4
const DEBRIS: int = 1 << 4    # layer 5

## What the tap_target ray may hit (never the ball or cosmetic debris).
const AIM_RAY_MASK: int = PLATFORM | BLOCK | CORE
