# AGENTS.md - Capitan's Walk

This is a game folder inside the DeskCanSaw Godot host, not a standalone
Godot project. Read `..\..\..\AGENTS.md` and `DESIGN.md` before changing rules.
The host project is two directories above this folder.

## Current scope

The playable build is a **dog + leash grey box** with centre-line trot, one
seeded squirrel lunge and Whistle. Final art, additional distractions, happiness,
route unlocks, store and multiplayer are not built.
Do not describe the prototype as the finished walk. The owner explicitly
authorized grey-box dog/leash work before Milestone 1's three-person playtest.
That playtest is still unverified and blocks progression tuning, not this milestone.
Owner decisions in DESIGN section 16 still block the features they name.

## Boundaries

- Register the game through `game.gd`; inherit `GameShell` and its scene.
  Do not add game-name branches or a second HUD/results framework to the host.
- `capitans_walk_options.gd` is preload-safe, constants-only data. Declare
  player-facing settings and bindings only when their behavior exists.
- Everything in `walk\` extends `RefCounted` and has no node, input, clock,
  physics-server or autoload dependencies. Pass input and forces into the model.
- The model uses metres, positive X along the path and positive Y upward.
  Renderers invert Y. Lateral Z is a separate balance axis.
- `walker_body.gd` advances in fixed 1/120-second steps. Motors and contacts,
  not a canned translation or a visual animation, move the walker.
- Views only read the model. The debug view is intentionally 2D; final art
  will be an isolated 3D viewport using `gl_compatibility`.
- `walk_state.gd` owns the coupled fixed clock. Apply the same measured rope force
  to the hand and collar with opposite signs. Whistle is edge-triggered in the
  model; never use a render-frame timer or teleport the dog back to the centre.
- The spike's `--walker-only` option preserves the original no-dog playtest.
- Runtime scripts must not depend on `tools\`, which is development-only.
- Keep knee contacts legal, opposing controls neutral, distance monotonic,
  and a relaxed double stance stable. Assists must not disable progression.
- Use tabs, static types and preload-by-path; avoid new global `class_name`s.
- Leave the supplied reference and the owner's staged changes intact.

## Validation

Run from this folder with the host at `..\..`:

```powershell
godot --headless --path ..\.. --import
godot --path ..\.. -- --game=capitans_walk
godot --path ..\.. --scene res://games/capitans_walk/tools/physics_spike.tscn -- --game=capitans_walk
godot --headless --path ..\.. --script res://games/capitans_walk/tests/manifest_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/walker_body_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/determinism_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/leash_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/dog_brain_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/walk_state_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/capitans_scene_test.gd -- --game=all
```

Run all 15 host suites with `--game=all` before marking scaffolding complete.
Use an isolated user profile for integration tests; tests must not overwrite
the player's saves. Windows GUI engine binaries need
`Start-Process -NoNewWindow -Wait -PassThru`; check the process's `ExitCode`.
There is no separate linter or formatter in the host.
The body suite deliberately logs two rejected nonfinite-input errors. The host
Saves suite also logs corrupt-fixture parse errors. Do not confuse these expected
negative cases with a script parse error or an exit-time resource leak; see
README's validation notes.

SceneTree tests must load gameplay at runtime after autoloads exist, rather
than preloading or naming `GameShell`. Do not claim a human playtest or rendered
coverage from headless model tests.
