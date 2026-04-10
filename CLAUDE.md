# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 melee combat prototype inspired by Absolver. GDScript throughout. No build system — open `project.godot` in the Godot 4 editor to run, export, or check for errors.

**Controls:** WASD move · mouse look · LMB attack · RMB parry · Space dodge · LShift absorb

## Running and checking the project

There is no CLI test runner. Validation happens inside the Godot editor:

- **Run:** F5 in the editor (or `godot --path . scenes/arena/Arena.tscn` from this directory if Godot is on PATH)
- **Check for script errors:** Scene > Reload Saved Scene, or Project > Reload Current Project — parse errors surface in the editor Output panel
- **Single scene:** F6 runs the currently open scene instead of the main scene

## Architecture

### The two-layer design

Combat logic and animation are deliberately separated:

- **`FighterStateMachine`** (RefCounted, not a Node) owns all frame counting and state transitions. It is the source of truth for what the fighter is *doing*.
- **`FighterAnimator`** is a thin wrapper around `AnimationTree` that is told what to play *after* the state has already changed. Animation timing is cosmetic; frame data in `MoveCard` is authoritative.

### Data flow: button press → hit resolution

```
InputMapper.get_input()
  → Fighter._physics_process()
    → FighterStateMachine.tick()
      → DeckRunner.get_current_move()   ← stance-gated
      → FSM: IDLE → STARTUP → ACTIVE
        → HitDetection.activate_hitbox()
          → Area3D.area_entered
            → target.receive_hit(move)
              → FSM checks: PARRY_ACTIVE / ABSORBING / DODGE i-frames / else _apply_hit()
```

### Key invariants

- **`_physics_process` only** — all combat logic lives here. `frame_counter` increments once per physics tick (fixed 60 fps via `ProjectSettings > Physics > 60`). Never use `_process` for combat.
- **`MoveCard.hitbox_offset`** positions the hitbox in the fighter's local space until a skeleton is rigged. After rigging, switch to `BoneAttachment3D` and remove the offset.
- **`DeckRunner`** holds a cursor over `ComboDeck.moves`. It scans forward from the cursor to find the first card whose `required_stance` matches `fighter.current_stance` (null = any). The cursor advances on recovery end or chain input.
- **Stances are metadata**, not FSM states. `fighter.current_stance` is a `Stance` resource reference read by `DeckRunner`; the FSM itself has no per-stance branching.
- **`_fighter` and `_fsm` are typed as `Node`/`RefCounted`** in sub-systems (DefensiveOptions, DeckRunner) to avoid circular class_name dependencies. Use explicit type annotations (`: bool`, `: int`) instead of `:=` when calling methods through these references, or GDScript will throw "cannot infer type" parser errors.

### Autoloads

| Autoload | Purpose |
|----------|---------|
| `GameManager` | Match/round state, fighter death reporting, round win tracking |
| `InputMapper` | 6-frame input buffer; call `InputMapper.get_input()` each physics tick |
| `HitStop` | `Engine.time_scale` freeze on hit; call `HitStop.trigger(damage)` from HitDetection |

### Adding a new move

1. Create a new `.tres` in `resources/moves/` with `script = MoveCard.gd`
2. Set `required_stance` / `exit_stance` to the appropriate `.tres` files in `resources/moves/stances/`
3. Add it to `resources/moves/moves_catalog.tres` so the DeckBuilder can see it
4. Add an animation state with the matching name to the fighter's `AnimationTree` (stub mode ignores missing animations)

### Adding a new stance

1. Create a `.tres` in `resources/moves/stances/` with `script = Stance.gd`
2. Set a unique `stance_id: StringName` — this is used for equality checks, not the resource path
3. Add corresponding idle/walk animation states to `AnimationTree`

### Collision layers

| Layer | Bit | Used by |
|-------|-----|---------|
| 2 | 1 | Hurtbox (`monitorable = true`) |
| 4 | 2 | Hitbox (`monitoring = true` during ACTIVE) |

### Git workflow

Every meaningful change should be committed and pushed so GitHub always has a revertable history. Use descriptive commit messages. The `.godot/` directory and `*.uid` files are gitignored — never force-add them.
