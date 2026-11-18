# AGENTS.md - Capitan's Walk

This is a game folder inside the DeskCanSaw Godot host, not a standalone
Godot project. Read `..\..\..\AGENTS.md` and `DESIGN.md` before changing rules.
The host project is two directories above this folder.

## Current scope

The owner-approved main game is a **first-person, low-poly 3D Park walk**.
Walking is automatic; keyboard/gamepad/multitouch steer the leash left/right
and Whistle recalls Capitan. Start at 100 points, earn one per safe metre,
and lose ten per model second after one continuous second off the path.
Zero points loses; reaching the provisional 200 m finish with points wins.
Human falls no longer end main gameplay. DESIGN section 0 supersedes the
original QWOP loop; sections 1-15 retain the legacy design, not current rules.

The old four-key ragdoll, five moods, sniffing, happiness, rhythm, Easy legs,
Steady and moving Park encounters remain in the default model/diagnostic
fixtures. Main gameplay uses telegraphed squirrel/pigeon/friendly-dog interest,
wet grip and slopes, with Walk speed and Long warnings as its live assists.
Help folds legends, never points, warnings or active touch pads. Touch retains
Thumbs, Left-handed and Right-handed layouts.

This is playable original 3D art, not Capitan's verified final likeness.
Pickups, route unlocks, store and multiplayer are not built. Neither the old
three-person physics playtest nor a new first-person human playtest is verified.
Do not tune progression or claim those gates passed. Owner decisions in
DESIGN section 16 still block the features they name.

## Boundaries

- Register the game through `game.gd`; inherit `GameShell` and its scene.
  Do not add game-name branches or a second HUD/results framework to the host.
- `capitans_walk_options.gd` is preload-safe, constants-only data. Declare
  player-facing settings and bindings only when their behavior exists.
- Everything in `walk\` extends `RefCounted` and has no node, input, clock,
  physics-server or autoload dependencies. Pass input and forces into the model.
- The legacy body uses metres, positive X along the path and positive Y up.
  Dog/path `Vector2` coordinates are forward X and lateral Z. The 3D view maps
  them to `(lateral, ground height, -forward)`; do not confuse lateral with height.
- `walk_state.gd` advances at 1/120 second. The first-person guide uses pacing,
  centring and hand motors; `walker_body.gd` keeps its legacy joint/contact solver.
  No animation or renderer may advance either model.
- Views only read the model. Gameplay uses `world\walk_view.gd` and an isolated
  real perspective viewport; `walker_debug_view.gd` remains diagnostic by default.
  Keep `gl_compatibility`; do not add a runtime dependency on another game.
- `walk_state.gd` owns the coupled fixed clock. Apply the same measured rope force
  to the hand and collar with opposite signs. Whistle is edge-triggered in the
  model; never use a render-frame timer or teleport the dog back to the centre.
- The spike's `--walker-only` option preserves the original no-dog playtest.
  It deliberately keeps classic four-key legs rather than the Easy-legs macro.
- First-person scoring tests the dog's model centre against the drawn outer
  edges. Returning resets grace; distance never decreases or rewards backtracking.
  Depletion beats a same-tick finish. Ending freezes the entire coupled clock.
- Legacy Easy legs authors input strengths on fixed ticks; releasing stops it,
  opposing choices cancel, and holding one choice never becomes an automatic walk.
- The owner chose fixed gamepad controls; only keyboard bindings are editable in
  Settings. Preserve left-stick strength in the main game, LT/RT in the spike,
  and one controller's ownership in both.
- `input\walk_controls.gd` monitors commands while paused, not physics. Clear held
  inputs on pause, restart, focus loss and device loss. Touch owns independent
  contacts, never shared InputMap actions; reserve space outside the walker view.
- Legacy rhythm observes actual contact edges, including driven feet landing after
  release. Bank stride points immediately; never erase them on a fall.
- Legacy sniffing requires sustained physical settling, not a passing gait's
  brief double stance. First-person pacing must not drain a hidden happiness meter.
- Park currently uses sixteen twenty-metre templates. Per-cell RNG makes queries
  independent of order; only the fixed model clock changes the retained window.
  Keep seams continuous, sniff gaps <=40 m and full hazard intervals >=6 m from
  rings across seams and adjacent event/boss reservations. Reservations are not
  implemented encounters. Do not populate item slots before pickups work.
- Main gameplay supplies a Park generator to `Walk`; its default and the physics
  spike remain flat baseline fixtures. Restart resets both route and dog seeds.
  Slope gravity is external force, not happiness-scaled drive; do not retune the
  original solver to fake a terrain effect. Legacy splashes follow shoe-contact edges.
- Legacy moving encounter state is bounded by the route window and advances only from
  `Walk.step()`. Telegraph each new action, including every sprinkler sweep.
  Ambient moods wait while an encounter is active; route queries consume no dog RNG.
  Jogger/flock/greeting interest uses happiness-scaled steering and the real rope.
  Water is a separate lateral force. A completed recall cancels interest, not water;
  cooldown alone must never immunize the dog against an unseen encounter.
  Only sustained physical settling can earn one play/greeting sniff per visit.
- HUD/callout priority comes from `Walk.cue_caption()`. First-person recall
  outranks interest; the path/grace/drain state remains independently visible.
  Legacy priority is recall/warnings, moving encounters, moods/sniffs, then terrain.
- Shell scores are now points. Keep distance as the headline and a separate
  stat; preserve synthetic shell scores by leaving `_finish_round()` alone.
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
godot --headless --path ..\.. --script res://games/capitans_walk/tests/path_walk_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/route_generator_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/hazards_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/input_sources_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/capitans_scene_test.gd -- --game=all
```

Run all 15 host suites with `--game=all` before marking scaffolding complete.
Use an isolated user profile for integration tests; tests must not overwrite
the player's saves. Windows GUI engine binaries need
`Start-Process -NoNewWindow -Wait -PassThru`; check the process's `ExitCode`.
There is no separate linter or formatter in the host.
The body suite deliberately logs two rejected nonfinite-input errors, and the
walk-state suite rejects invalid dog happiness/profile data before any coupled
state changes. The path suite rejects nonfinite steering. The route suite
rejects nonfinite/reversed window bounds.
The host Saves suite also logs corrupt-fixture parse errors.
Do not confuse these expected negative cases with a script parse error or an
exit-time resource leak; see README's validation notes.

SceneTree tests must load gameplay at runtime after autoloads exist, rather
than preloading or naming `GameShell`. Do not claim a human playtest or rendered
coverage from headless model tests.
The input/scene suites inject Godot keyboard, joystick and multitouch events.
These verify the actual adapters and shared results, not physical hardware usability.
Run the scene suite without `--headless` for real 3D rendering/draw-call coverage.
The current tutorial uses `first_person.ogv` and `first_person_poster.webp`;
preserve the older staged poster/cover. The shared recording wrappers target
legacy filenames, so use README's explicit current-media commands instead.
