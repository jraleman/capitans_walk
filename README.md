# Capitan's Walk

The first playable build is a **walker-only physics prototype** for the game
in [DESIGN.md](DESIGN.md). Four keys drive real joint motors on a narrow, flat
path. There is no canned forward movement.

Capitan, his leash, distractions, touch/gamepad input, final 3D art and
progression are not implemented yet. The working title does not settle the
owner's final spelling or permanent save-directory decision.

## Controls

| Key | Action |
| --- | --- |
| Q | Left thigh forward, right thigh back |
| W | Right thigh forward, left thigh back |
| O | Bend the left knee, straighten the right |
| P | Bend the right knee, straighten the left |
| R | Restart immediately, including from results |
| Escape | Pause |

Keyboard actions are rebindable in Settings. Equal opposing strengths cancel.
Release everything to settle into standing; knee contact alone is legal.
**Steady** adds torso support, and **Walk speed** offers 100%, 85% and 70% model
time without changing the fixed 120 Hz solver.

The development spike also accepts Left/Right arrow **sideways tugs** to compare
bracing and striding. Those tugs are not controls in the main game.

## Run

This folder is a game inside the DeskCanSaw host, not a standalone Godot
project. Run from this folder with Godot 4.7 or newer:

```powershell
godot --headless --path ..\.. --import
godot --path ..\.. -- --game=capitans_walk
godot --path ..\.. --scene res://games/capitans_walk/tools/physics_spike.tscn -- --game=capitans_walk
```

The normal launch uses the shared title, instructions, pause, results and stats
screens. The second scene goes directly to the development playtest.
Permanent standalone export/save tags remain deferred; this is not a release build.

## Validation

```powershell
godot --headless --path ..\.. --script res://games/capitans_walk/tests/manifest_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/walker_body_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/determinism_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/capitans_scene_test.gd -- --game=all
```

Use an isolated host/user profile for integration and framework suites, not a
player's saves. Include the host's `export_presets.cfg` in that copy. On Windows,
GUI engine binaries require `Start-Process -NoNewWindow -Wait -PassThru`; check
both exit status and diagnostics. There is no separate linter or formatter.

Verified on Godot 4.7.2: all four game suites pass. The authored binary gait
**Q+O -> Q+P -> W+P -> W+O**, held for 0.1 s per pair, reaches **13.17 m in
100 simulated seconds**. Neutral standing survives 100 seconds, repeated
60-second input streams match exactly, changing gait state matches at
30/60/144 render FPS, and a three-second hitch discards no model time.
The scene suite passes headlessly and in a real graphics window, including
rebinding, live assists, pause, off-path results, in-place restart and
portrait/landscape/ultrawide bounds. Normal boot -> Play -> Instructions ->
the running walker and direct spike launch are also verified.

All 15 framework suites pass their assertions and exit 0. Some batched headless
Lives/Single-game runs still report resource-cleanup errors at shutdown
(`ui_back.wav` in Lives); the overall framework run is **not consistently
clean**. Nonfinite-input and damaged-backup tests deliberately log their
rejected inputs; unexpected script or cleanup errors must not be ignored.

These are automated results, **not** the required three-person playtest.
Measure beginner time to 5 m, a practised player's best and sideways-fall
fairness before beginning dog/leash mechanics or tuning unlock distances.
See [TODO.md](TODO.md) for the unchecked exit gate and later milestones.

## Prototype walkthrough

`assets\video\tutorial.ogv` and its WebP poster are original footage of the real
scene, labelled as a physics prototype. The game-owned
`tools\tutorial_driver.gd` plugs into the host's `tools\tutorial_capture.tscn`:
it drives keyboard actions, verifies walking/settling/restart and never assigns
poses or scores.

The host PowerShell recorder's game whitelist does not yet include this game.
For regeneration, use its Movie Maker scene with `--game=capitans_walk`,
`--resolution 1280x720 --fixed-fps 30 --write-movie <temporary AVI>`, then encode
Theora at 960x540, 30 FPS, quality 7 and a 640x360 WebP poster at 9 seconds.
Audio is intentionally omitted; the captions carry the lesson.