# Capitan's Walk

The playable build is a **dog + leash grey-box prototype** for the game in
[DESIGN.md](DESIGN.md). Four keys drive real joint motors on a narrow, flat path.
Capitan trots ahead, pulls a spring-damper rope and lunges at one seeded squirrel
distraction. There is no canned forward movement.

Additional distractions, happiness, routes, touch/gamepad input, final 3D art
and progression are not implemented yet. The working title does not settle
the owner's final spelling or permanent save-directory decision.

## Controls

| Key | Action |
| --- | --- |
| Q | Left thigh forward, right thigh back |
| W | Right thigh forward, left thigh back |
| O | Bend the left knee, straighten the right |
| P | Bend the right knee, straighten the left |
| Space | Recall Capitan after 0.3 s; six-second model-time cooldown |
| R | Restart immediately, including from results |
| Escape | Pause |

Keyboard actions are rebindable in Settings. Equal opposing strengths cancel.
Release everything to plant and settle; knee contact alone is legal.
Capitan's `!`, caption and original warning tone precede his 0.4-second lunge
by 0.8 seconds. Double stance is safer than striding into the pull. W+P can
help lean back; the readout shows the actual torso angle and rope tension.
Whistle brings him toward the centre line; release before calling again.
**Steady** adds torso support, and **Walk speed** offers 100%, 85% and 70% model
time without changing the fixed 120 Hz solver.

The rope starts with 0.3 m of slack, goes taut at 1.8 m horizontal separation,
and clamps force at 260 N. Both endpoints receive equal/opposite X/Z force;
the existing hand/shoulder spring carries the load into the torso.
The development spike also accepts Left/Right arrow **sideways tugs** to compare
bracing and striding. Those tugs are not controls in the main game.

## Run

This folder is a game inside the DeskCanSaw host, not a standalone Godot
project. Run from this folder with Godot 4.7 or newer:

```powershell
godot --headless --path ..\.. --import
godot --path ..\.. -- --game=capitans_walk
godot --path ..\.. --scene res://games/capitans_walk/tools/physics_spike.tscn -- --game=capitans_walk
godot --path ..\.. --scene res://games/capitans_walk/tools/physics_spike.tscn -- --game=capitans_walk --walker-only
```

The normal launch uses the shared title, instructions, pause, results and stats
screens. The direct scene tests dog/leash bracing; `--walker-only` preserves
the original walker-only human playtest without dog forces.
Permanent standalone export/save tags remain deferred; this is not a release build.

## Validation

```powershell
godot --headless --path ..\.. --script res://games/capitans_walk/tests/manifest_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/walker_body_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/determinism_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/leash_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/dog_brain_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/walk_state_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/capitans_scene_test.gd -- --game=all
```

Use an isolated host/user profile for integration and framework suites, not a
player's saves. Include the host's `export_presets.cfg` in that copy. On Windows,
GUI engine binaries require `Start-Process -NoNewWindow -Wait -PassThru`; check
both exit status and diagnostics. There is no separate linter or formatter.

Verified on Godot 4.7.2: all seven game suites pass. The walker-only binary gait
**Q+O -> Q+P -> W+P -> W+O**, held for 0.1 s per pair, reaches **13.17 m in
100 simulated seconds**. Neutral standing survives 100 seconds, repeated
60-second input streams match exactly, changing gait state matches at
30/60/144 render FPS, and a three-second hitch discards no model time.
The scene suite passes headlessly and in a real graphics window, including
rebinding, live assists, pause, off-path results, in-place restart and
portrait/landscape/ultrawide bounds. Normal boot -> Play -> Instructions ->
the running walk and direct spike launch are also verified.

The coupled model preserves exact body/dog/rope/timer/RNG state for 60 seconds,
agrees at 30/60/144 FPS through a real lunge, and drops no three-second hitch
time. A graded W+P brace holds **8.6 degrees back** against **17.3 N** of trot
tension; it survives the lunge with much less pitch than a forward lean.
Real rebound Whistle input, delayed recall, pause and complete same-seed
restart are covered through the gameplay scene.

All 15 framework suites pass their assertions, exit 0 and finish without
unexpected script or shutdown resource errors. The host's Lives/Single-game
suites now release UI audio before quitting, following its existing test
teardown pattern. Nonfinite-input and damaged-backup tests deliberately log
their rejected inputs; unexpected script or cleanup errors must not be ignored.

These are automated results, **not** the required three-person playtest.
The owner explicitly authorized this grey-box milestone before that playtest.
Beginner time to 5 m, a practised player's best and sideways-fall fairness
remain unrecorded; progression distances must not be tuned from automated data.
See [TODO.md](TODO.md) for the remaining playtest gate and later milestones.

## Prototype walkthrough

`assets\video\tutorial.ogv` and its WebP poster are original footage of the real
scene, labelled as a grey-box prototype. The game-owned
`tools\tutorial_driver.gd` plugs into the host's `tools\tutorial_capture.tscn`:
it drives keyboard actions, verifies walking, warning/lunge, whistle recall,
settling and restart, and never assigns poses or scores. The generated tones
are placeholders, not recordings of Capitan's bark.

The host PowerShell recorder's game whitelist does not yet include this game.
For regeneration, use its Movie Maker scene with `--game=capitans_walk`,
`--resolution 1280x720 --fixed-fps 30 --write-movie <temporary AVI>`, then encode
Theora at 960x540, 30 FPS, quality 7 and a 640x360 WebP poster at 9 seconds.
Audio is intentionally omitted; the captions carry the lesson.