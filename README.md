# Capitan's Walk

The playable build is a **seeded Park grey-box prototype** for the game in
[DESIGN.md](DESIGN.md). Four independent controls drive real joint motors on a
narrow, endlessly streamed path with puddles, slopes and telegraphed Park encounters.
Capitan trots ahead, pulls a spring-damper rope and reacts to five seeded
distractions. Sniffing, happiness, rhythm points and optional two-key Easy legs
are playable. There is no canned forward movement.

Keyboard, fixed gamepad and independent multitouch controls are playable.
Other routes, items/events, final 3D art
and progression are not implemented yet. The working title does not settle
the owner's final spelling or permanent save-directory decision.

## Controls

| Keyboard | Fixed gamepad | Action |
| --- | --- | --- |
| Q | LB | Left thigh forward, right thigh back |
| W | LT (analogue) | Right thigh forward, left thigh back |
| O | RB | Bend the left knee, straighten the right |
| P | RT (analogue) | Bend the right knee, straighten the left |
| A / D | D-pad left / right | With Easy legs on: choose the left / right motor stride |
| Space | A | Recall Capitan after 0.3 s; six-second model-time cooldown |
| R | Y or Back | Restart immediately, including from results |
| Escape | Start | Pause |

Keyboard actions are rebindable in Settings; gamepad controls are fixed by the
owner's choice. Triggers preserve feathered strengths, with a small release
deadzone. One active controller owns the motors until reset or disconnect.
Start also resumes pause and backs out of nested Settings before resuming.

Touch controls appear on touchscreens or the first screen touch on a hybrid
desktop. Four independent pads keep thighs on the left and calves on the right;
Whistle, Restart and Pause have their own buttons. Game settings offer
**Thumbs / Left-handed / Right-handed** layouts. Easy legs replaces the top
motor pads with left/right stride choices, keeping the two B pads for bracing.
Whistle shows its model-time cooldown and readiness on the button.
Dragging off releases that finger; another finger on the same pad stays held.
The controls reserve space below the walker, with a compact landscape HUD.
Keyboard, gamepad and touch can coexist without releasing each other's inputs.
Pause, focus loss and restart clear held controls; touch-layout/viewport changes
release contacts without releasing the other sources.

Equal opposing strengths cancel.
Release everything to plant and settle; knee contact alone is legal.
Capitan's `!`, caption and original warning tone precede his 0.4-second lunge
by 0.8 seconds. Double stance is safer than striding into the pull. W+P can
help lean back; the readout shows the actual torso angle and rope tension.
Whistle brings him toward the centre line; release before calling again.
**Easy legs** plays the authored bend/plant phases on the same four motors.
Hold each leg for its 0.2-second stride, then choose the other or release.
Holding both cancels; holding one finishes just one stride, not an automatic
walk. Manual W+P bracing remains available when the Easy keys are released.
**Steady** adds torso support, **Walk speed** offers 100%, 85% and 70% model
time, and **Long warnings** doubles every telegraph, including its remaining
time when enabled live. None changes the fixed 120 Hz solver.

## The grey-box walk

| Icon | Mood | Counter |
| --- | --- | --- |
| ! | Squirrel: sharp forward/sideways lunge | Plant both feet and lean back |
| H | Hydrant: slow sideways drag, then sniff | Stop and let him sniff |
| V | Pigeon: three to five alternating tugs | Stand still; step between beats |
| ~ | Food: sustained forward or backward drag | Lean against the indicated direction |
| Z | Sit-down protest: stationary anchor | Stop for two uninterrupted seconds |

Each warning has its own caption, icon and original synthesized cue. The first
warning remains the squirrel lesson; subsequent choices are seeded and weighted
by Capitan's profile. Later intervals depend on distance and happiness.
There are no recorded dog barks.

Grass rings mark generated, hazard-free sniff spots, starting at **4 m**.
Sustain a settled stance nearby to let Capitan sniff.
Happiness starts at **60/100**: sniffing fills **4/s**; walking without a sniff
drains **1/s after 20 s**. Calling him off a sniff costs **10**, actually pulling
a protest costs **15 once**, and a taut-rope near-fall costs **5 once**.
Lower happiness increases pulling and distraction frequency; zero means
determined, not a failed walk. Treat/event fills belong to later milestones.

An alternating foot plant **0.45-0.9 s** after the previous one, within
**15 degrees** of upright, builds rhythm. Strut/Swagger/Parade/Best in Show
start at **5/12/25/50** good strides and bank **x1.5/x2/x3/x4**.
Each driven plant banks a provisional **10 points** before its combo multiplier;
landing after releasing the key still counts. Knees, repeated feet, mistimed
plants or a lean beyond 30 degrees break the combo, never the bank.
Combos of five or more also add one happiness per good stride.

Distance remains the headline. Final points apply the ending happiness
multiplier **x1.0-x2.0 once**; results show both, the real cause and Capitan's
one-to-five-wag verdict. Stats retain foot plants/falls and add rhythm, model
time, happiness, sniffs and leash measurements. An assist badge stays set if
any assist was used, even when switched off before ending. The best-walks table
and its assisted presentation are not built yet.

The rope starts with 0.3 m of slack, goes taut at 1.8 m horizontal separation,
and clamps force at 260 N. Both endpoints receive equal/opposite X/Z force;
the existing hand/shoulder spring carries the load into the torso.
The development spike also accepts Left/Right arrow **sideways tugs** to compare
bracing and striding. Those tugs are not controls in the main game.

## Seeded Park terrain

The main game currently uses **seed 0**; Restart repeats it. There is no player
seed/route selector yet. The first 20 m stays flat for the original leash lesson.
After that, sixteen authored 20 m templates supply three provisional difficulty
tiers, wet patches, rises, dips, rest areas and moving encounters. The 50/150 m tier bands
follow the design, not tuned unlock distances.

Each cell has its own seed. Streaming retains only a window around both actors;
previewing, backtracking and eviction cannot consume dog RNG or change the route.
Seams are continuous and duplicate vertices are removed before contact solving.
Sniff rings remain at most 40 m apart and at least 6 m clear of the **whole
hazard interval**, including neighbouring chunks. Fixed event/boss positions
reserve quiet space and shift rings safely, even at adjacent reservations.
Those are data only: there are no playable events or bosses yet.

**~ PUDDLE** patches lower actual contact friction from 0.90 to **0.30** for
their width. Shoe-contact edges produce an original splash tone and caption,
not repeated splashes while standing. **^ SLOPE** profiles are the actual
contact geometry; gravity acts on the walker and the dog, outside the dog's
happiness-scaled drive. The HUD gives readable surface feedback without
displacing dog warnings or recall. The view never advances the model.

| Park cue | Physical effect and counter |
| --- | --- |
| * Sprinkler | Ticks for 0.8 s before each sideways water sweep. Plant both feet; stopping nearby can let Capitan play/sniff. Whistle cancels his interest, **not the water**. |
| J Jogger | Approaches from the front, passes and draws Capitan backward through the actual rope. Brace or Whistle. |
| VV Pigeon flock | Three alternating sideways tug beats. Plant; step between beats or Whistle. This is separate from the seeded pigeon **mood**. |
| D Friendly dog | Continuing to stride tugs toward a greeting; sustained settling nearby can earn a real sniff. |

Long warnings doubles these telegraphs, including an already-visible warning.
Only one environmental encounter runs at once; ordinary moods wait their turn.
Each cue has a distinct original tone, written counter and a model-driven actor.
Sniff opportunities use the same physical settling and happiness rules as other
sniffs, once per visit. They are **not** the hazard-free grass rings.
Recall takes the same 0.3 s and holding never repeats; a prior quiet recall's
cooldown does not protect against an unseen encounter.
Evicted encounters release their state; a revisit gets a fresh warning, not
an unannounced action. Item pickups and power-ups remain unfinished.
The flat model fixtures and menu-free physics spike retain the earlier baseline.

## Run

This folder is a game inside the DeskCanSaw host, not a standalone Godot
project. Run from this folder with Godot 4.7 or newer:

```powershell
godot --headless --path ..\.. --import
godot --path ..\.. -- --game=capitans_walk
godot --path ..\.. --scene res://games/capitans_walk/tools/physics_spike.tscn -- --game=capitans_walk
godot --path ..\.. --scene res://games/capitans_walk/tools/physics_spike.tscn -- --game=capitans_walk --walker-only
godot --path ..\.. --scene res://games/capitans_walk/tools/chunk_preview.tscn -- --game=capitans_walk --route-seed=1 --chunk-index=1
```

The normal launch uses the shared title, instructions, pause, results and stats
screens. The direct scene tests dog/leash bracing; `--walker-only` preserves
the original walker-only human playtest without dog forces.
That mode deliberately retains classic legs; Steady and Walk speed still work.
The development chunk preview shows generated geometry, sniff/surface/moving slots
and explicitly inactive reservations, not a simulated walk. Left/Right changes
the cell, R changes the seed, and Escape quits.
Permanent standalone export/save tags remain deferred; this is not a release build.

## Validation

```powershell
godot --headless --path ..\.. --script res://games/capitans_walk/tests/manifest_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/walker_body_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/determinism_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/leash_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/dog_brain_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/walk_state_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/route_generator_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/hazards_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/input_sources_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/capitans_walk/tests/capitans_scene_test.gd -- --game=all
```

Use an isolated host/user profile for integration and framework suites, not a
player's saves. Include the host's `export_presets.cfg` in that copy. On Windows,
GUI engine binaries require `Start-Process -NoNewWindow -Wait -PassThru`; check
both exit status and diagnostics. There is no separate linter or formatter.

Verified on Godot 4.7.2: all ten game suites pass. The walker-only binary gait
**Q+O -> Q+P -> W+P -> W+O**, held for 0.1 s per pair, reaches **13.17 m in
100 simulated seconds**. Neutral standing survives 100 seconds, repeated
60-second input streams match exactly, changing gait state matches at
30/60/144 render FPS, and a three-second hitch discards no model time.
The scene suite passes headlessly and in a real graphics window, including
rebinding, live assists, pause, off-path results, in-place restart and
portrait/landscape/ultrawide HUD bounds and rendered results/stat panels.
The same physical-key, joystick and multitouch gait reaches **2.13 m in 1571
fixed ticks**, then a genuine off-path ending and shared results, with identical
complete model/RNG/scoring snapshots across all three adapters. No fall or pose
is assigned for those walks. Input tests cover analogue triggers, controller
ownership/disconnection, independent fingers, mouse emulation, focus cleanup,
Easy legs and one-shot commands. All three touch layouts have rendered bounds
and non-overlapping native-button coverage.
Normal boot -> Play -> Instructions ->
the running walk, direct spike launch and rendered chunk previews are also verified.

Route tests check four seeds through 4 km, including coincident and adjacent
event/boss reservations; bounded streaming/backtracking reaches 20 km. Actual
puddle contacts slide more than dry pavement and do not farm splash events.
Wet coupled state matches at 30/60/144 FPS, freezes on ending and resets exactly.
The seed-1 motor gait with warning-triggered recall physically reaches a puddle
at **31.51 m / 23457 ticks**; no distance, pose or score is assigned.
Separate, explicitly placed terrain fixtures check rendered puddles/slopes from
portrait to ultrawide; these are not presented as walked distances.

Moving-hazard fixtures separately verify real sprinkler sway, backward jogger
rope force, three flock reversals, settled versus striding greetings, delayed
recall and caption/audio priority. State matches at 30/60/144 FPS, survives a
three-second hitch, freezes on ending and remains bounded through 20 km.
The seed-731 motor walk reaches a generated jogger at **52.09 m / 40595 ticks**,
releases the motors to brace, and measures **39 N of backward rope force**.
The same walk runs through the scene's actual input adapter, without assigned
poses, scores, distance or translation. New actor/warning captures are explicit
fixtures, not claims of naturally walked kilometres.

The coupled model preserves exact body/dog/rope/timer/RNG state for 60 seconds,
agrees at 30/60/144 FPS through a real lunge, and drops no three-second hitch
time. A graded W+P brace holds **8.6 degrees back** against **17.3 N** of trot
tension in the earlier leash milestone; at 60 happiness the current brace is
**8.59 degrees at 17.52 N** and still controls the same real lunge.
Real rebound Whistle input, delayed recall, pause and complete same-seed
restart are covered through the gameplay scene.

The two-key authored gait reaches **4.76 m in 30 seconds**, exactly matching
its four-key equivalent through real recalls. Both modes agree at 30/60/144 FPS
on physics, mood timers, happiness, contact/score history and macro phase.
Focused tests cover all five pull shapes, every doubled warning, sniff/protest
costs, rhythm boundaries and tier banking, released-foot scoring and the
latched assist badge. Passing foot plants do not silently start a sniff or
postpone the squirrel lesson.

All 15 framework suites pass their assertions, exit 0 and finish without
unexpected script or shutdown resource errors. The host's Lives/Single-game
suites now release UI audio before quitting, following its existing test
teardown pattern. Nonfinite-input and damaged-backup tests deliberately log
their rejected inputs; the walk suite also rejects invalid happiness/profile
data without advancing either endpoint, macro or bank. The route suite deliberately
rejects nonfinite/reversed window bounds without replacing terrain. Unexpected script or
cleanup errors must not be ignored.

These are synthesized Godot events through the real adapters and scenes,
**not** physical controller/mobile hardware testing or the required three-person playtest.
The owner explicitly authorized this grey-box milestone before that playtest.
Beginner time to 5 m, a practised player's best and sideways-fall fairness
remain unrecorded; progression distances must not be tuned from automated data.
See [TODO.md](TODO.md) for the remaining playtest gate and later milestones.

## Prototype walkthrough

`assets\video\tutorial.ogv` and its WebP poster are original footage of the real
scene, labelled as a grey-box prototype. The game-owned
`tools\tutorial_driver.gd` plugs into the host's `tools\tutorial_capture.tscn`:
it remains a keyboard introduction, verifies walking, warning/lunge, whistle recall,
settling and restart, and never assigns poses or scores. The generated tones
are placeholders, not recordings of Capitan's bark.

The host PowerShell recorder's game whitelist does not yet include this game.
For regeneration, use its Movie Maker scene with `--game=capitans_walk`,
`--resolution 1280x720 --fixed-fps 30 --write-movie <temporary AVI>`, then encode
Theora at 960x540, 30 FPS, quality 7 and a 640x360 WebP poster at 9 seconds.
Audio is intentionally omitted; the captions carry the lesson.