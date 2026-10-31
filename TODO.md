# Capitan's Walk — TODO

Progress tracker for implementing [`DESIGN.md`](DESIGN.md). Sections follow the
milestones in DESIGN §15, with a scaffolding phase first. Tick a box only when
the item works **and** its tests pass. Each phase ends with an exit check.

`§n` points at the matching section of `DESIGN.md`. Run commands from
`godot-base/`. Framework rules from the root `AGENTS.md` still apply.

---

## Blocked on the owner (DESIGN §16)

These change names, keys or scope that become permanent once shipped. Nothing
below that depends on one should start until it is answered.

- [ ] **Title and spelling** (§16.1) — "Capitan's Walk" or "Capitán's Walk".
      This fixes `custom_user_dir_name` forever and blocks the `project.godot`
      feature-tag entries in Milestone 10.
- [x] **Capitan's look, breed and size** (§6.1) — `capitans.jpg`; a
      small-to-medium terrier-type mix; collars are store items (§9.2).
- [ ] **Capitan's remaining details** (§16.2) — habits, a photo to check the
      illustration's proportions, and permission to record his barks. Blocks
      the final dog proportions (Milestone 5) and his voice (Milestone 9).
- [ ] **How the dog is picked** (§6.4, §16.3) — a generic per-seat companion
      list on `GameManifest` (a framework change, as data), or a tunable.
      Blocks dog selection in Milestone 7 and the pass-the-leash setup.
- [ ] **Narrator voice-over in v1?** (§16.4) — who voices it. Captions
      ship either way.
- [ ] **Pass the leash in v1, with 2 or 3 seats?** (§16.5) — sets
      `max_local_players`.
- [ ] **Bosses** (§16.6) — keep Chalupa next to Dulce's chihuahua heroine?
      Five bosses in v1, or two?
- [ ] **Daily seed day boundary** (§16.7) — local midnight or UTC.
- [ ] **Assisted walks** (§16.8) — their own leaderboard tab, or a badge only.

## Discrepancies found while planning

- [ ] The folder's `README.md` says `# julios_walk`, but the folder and id are
      `capitans_walk`. Confirm and fix it along with the title (§16.1).
- [ ] `capitans.jpg` sits at the folder root, so Godot imports it and every
      export preset ships it. Move it to `reference/` with a `.gdignore`, or
      exclude it from the presets.
- [ ] The project targets Godot **4.7**, but this machine has **4.6.2**
      (`/usr/bin/godot`). Install 4.7 before trusting any test result.
- [ ] `menu_order = 11` assumes Dulce's Adventure (`9`) and Sailor Man (`10`)
      keep their planned slots. Both are design-only so far. Keep `11` anyway so
      the order doesn't shift later.
- [ ] `control_bindings` are keyboard-only. The gamepad is polled in
      `gameplay.gd`, as Cube Trials does, so gamepad buttons are not rebindable
      in Settings. Accept that, or raise it as framework data.
- [ ] The best-walks table and photo mode are game-owned screens inside the
      results flow, not framework screens. Check they fit the shell's results
      panel before building them (Milestone 8).

---

## Phase 0 — Scaffolding

As soon as `game.gd` exists, `GameCatalog` loads it and every framework suite
sweeps it. Start with a stub that passes them, and keep them green from here on.

- [ ] Commit `DESIGN.md` and this `TODO.md` to the game repository.
- [ ] A folder `AGENTS.md` with game-specific agent notes, as Chicken Pit has.
- [ ] `capitans_walk_options.gd` — constants-only: `GAME_ID`, tunable keys (§10),
      binding keys (§3.2, §10), with empty `ROUTES`, `WALKERS`, store and gallery for now.
- [ ] `game.gd` — minimal manifest (§11.4): id, title, tagline, `menu_order = 11`,
      `CONTROL_STYLE_CUSTOM_KEYS`, `uses_shell_round_rules = false`,
      `supports_cpu_opponent = false`, tunables, bindings. Leave multiplayer off
      until Milestone 9.
- [ ] `gameplay.tscn` (inherits `game_shell.tscn`) + `gameplay.gd` (`extends
      GameShell`, `game_id()`, `super(value)` in the reduced-motion and
      intense-effects overrides).
- [ ] A `tests/` folder and a smoke test that loads the manifest by path.
- [ ] `godot --headless --path . --import`
- [ ] **Exit:** all 15 framework suites exit 0 with `--game=all`, and
      `godot --path . -- --game=capitans_walk` opens the stub.

## Milestone 1 — Physics spike (§3) ⚠ riskiest

- [ ] `walk/input_frame.gd` — `{q, w, o, p: 0..1, whistle}`.
- [ ] `walk/walker_body.gd` (`RefCounted`, 120 Hz, every constant at the top):
  - [ ] Verlet particles: head, neck, hip, knees, ankles, toes, hand
  - [ ] Bone distance constraints and joint angle limits (no forward knees)
  - [ ] Joint motors: Q/W thighs, O/P knees, opposing keys cancel, analogue strength
  - [ ] A relaxed neutral stance with no input, which stands indefinitely on flat ground
  - [ ] Ground polyline contacts with per-surface friction
  - [ ] Lateral sway `z` (§3.3): inverted pendulum, stance spring by contact
        phase, foot plants with a catch-step
  - [ ] End detection: fall (head or neck contact, or torso past 80° for 0.5 s),
        off the path; a knee-scoot is not a fall
  - [ ] Distance as the furthest hip x
- [ ] `walk/walker_profiles.gd` — Sam only for now.
- [ ] `tools/physics_spike.tscn` — debug 2D draw of the particles, the path
      edges and the `z` gauge, with live keys. Dev-only.
- [ ] `tests/walker_body_test.gd` — stance, scripted gait ≥ 10 m, end rules.
- [ ] `tests/determinism_test.gd` — same seed and inputs → identical state at 60 s.
- [ ] **Exit:** a playtest with at least three people. Record here how long a first-time
      player takes to reach 5 m (target ≤ 2 min), a practised player's best
      (target 50 m) and whether the sideways falls felt fair. Tune the unlock
      distance (§5.2) from these numbers before moving on.

## Milestone 2 — Leash and Capitan, grey box (§4)

- [ ] `walk/leash.gd` — spring-damper, slack zone, clamped force, `(x, z)`
      direction, wrist-looped (never dropped).
- [ ] The arm spring carries the leash force into the torso at shoulder height.
- [ ] `walk/dog_brain.gd` — trot on the centre line, keeping the leash just taut.
- [ ] One distraction end to end: the squirrel lunge, with its telegraph.
- [ ] Tune the brace: a steady trot pull holds an 8° lean back (§4.4).
- [ ] Whistle: ends a distraction after 0.3 s, 6 s cooldown (§4.5).
- [ ] `tests/leash_test.gd`.
- [ ] **Exit:** on the spike, leaning into the pull is noticeably easier than
      fighting it, and a lunge is survivable from double stance.

## Milestone 3 — The walk (§3.5, §4.3, §7.5–§7.6)

- [ ] `walk/walk_state.gd` — owns body, leash and dog; fixed step with an
      accumulator; distance; ending and its cause.
- [ ] The remaining distractions: hydrant drag, pigeon zigzag, food-smell drag,
      sit-down protest, each with a caption, an icon and a sound.
- [ ] Happiness: fill and drain table, pull, distraction-rate and score multipliers.
- [ ] Sniff spots: standing still nearby lets him sniff.
- [ ] Perfect-rhythm combo: good-stride detection, tiers, break rules, banking.
- [ ] Scoring and Capitan's verdict (one to five wags).
- [ ] Assists: Easy legs macro (two keys), Steady, Walk speed, Long warnings.
- [ ] `walk/dog_profiles.gd` — Capitan only for now.
- [ ] `input/key_source.gd`, `input/pad_source.gd` (analogue triggers),
      `input/touch_pads.gd` (four pads, independent multitouch).
- [ ] `ui/walk_hud.gd` — distance, happiness bone, balance bubble, combo,
      telegraph bubble; numbers and icons, never colour alone.
- [ ] `gameplay.gd` hooks (§11.3): one shell round = one walk; shell end-of-round
      path; `_round_totals`, `_player_stats`, `_describe_round_outcome`,
      `_round_highlight_summary`.
- [ ] Restart resets the model and view in place in under 2 s.
- [ ] `tests/dog_brain_test.gd`, `tests/walk_state_test.gd` (including Easy legs
      ≥ four keys), `tests/capitans_scene_test.gd` (first pass).
- [ ] **Exit:** a full walk on a flat grey-box path to the results panel, by
      keyboard, gamepad and touch. Framework suites green.

## Milestone 4 — Routes (§5.1, §5.3)

- [ ] `walk/route_chunks.gd` — chunk format: length, ground profile, surfaces,
      sniff spots, item slots, hazard slots, tier.
- [ ] `walk/route_generator.gd` — seeded and endless; sniff spacing, hazard
      spacing per tier, set-piece distances.
- [ ] `walk/hazards.gd` — puddle, sprinkler, jogger, pigeon flock, other dog, slope.
- [ ] The Park chunk pool (about 12 chunks across 3 tiers).
- [ ] Items (§7.1): treat, treat bag (Calm mode), tennis ball (Super-steady).
- [ ] `tools/chunk_preview.tscn` — draw one chunk and its slots. Dev-only.
- [ ] `tests/route_generator_test.gd`.
- [ ] **Exit:** an endless Park walk in grey box, the same route for the same seed.

## Milestone 5 — The 2.5D world (§8)

- [ ] `world/mesh_builder.gd` — copy from `cube_trials/world/` and adapt.
- [ ] `world/walk_view.gd` — isolated `SubViewport`, side camera raised ~15°,
      look-ahead, reduced-motion follow.
- [ ] `world/walker_rig.gd` — soft toy figure whose bones copy the model's
      particles exactly; hat, scarf and shoe sockets.
- [ ] `world/dog_rig.gd` — Capitan from `capitans.jpg` (§6.1), a small-to-medium
      terrier-type mix (~40 cm at the shoulder): white wiry coat,
      black head with a white blaze, tan eyebrows and cheeks, floppy black ears,
      curled plumed tail, big dark eyes, tongue-out grin. Procedural trot bounce,
      ear lift, tail wag from happiness and telegraph poses; calmer under
      reduced motion. A collar socket the leash clips onto, plus hat, scarf
      and bootie sockets. Check proportions against a photo (blocked on §16.2).
- [ ] `world/leash_rope.gd` — sagging curve, equipped colour.
- [ ] `world/route_scenery.gd` — Park props batched from chunk data.
- [ ] `audio/walk_audio.gd` — footsteps per surface, collar jingle, splashes,
      falls, placeholder barks, music that ducks under telegraphs.
- [ ] `tests/walk_view_test.gd` *(window)* — walker, Capitan and path edges in
      shot, balance bubble readable, < 60 draw calls, portrait → ultrawide,
      touch pads clear of the walker.

## Milestone 6 — Events and the first boss (§5.4–§5.5)

- [ ] `walk/events.gd` — set-piece runner with a "stand still" and a "walk on"
      outcome.
- [ ] Cat showdown, dropped hot dog, sudden rainstorm (no lightning flash with
      intense effects off).
- [ ] Chalupa: bark rhythms, the circling charge, leash wraps and unwinding,
      "gift-wrapped" ending; a visual beat strip for her barks.
- [ ] `tests/events_test.gd`.
- [ ] **Exit:** a Park walk meets every event and Chalupa, and each one has
      both outcomes reachable.

## Milestone 7 — Content (§5.2, §6, §9.1)

- [ ] Beach Boardwalk: banana peels, seagulls, skateboarders, wet planks; the
      Seagull Gang.
- [ ] City Rush Hour: crowds, food carts, manhole steam; the Crosswalk.
- [ ] Snowy Hill: ice, sledders, snowballs, slopes; the Snowplough.
- [ ] Fairground: popcorn, balloons, the mascot, other dogs; the Marching Band.
- [ ] Each route's scenery and its signature event.
- [ ] Dogs: Waffles, Zippy, Duchess — profiles and rig proportions.
- [ ] Walkers: Grandma Rosa (cane as a third contact), Stretch, Dash.
- [ ] Dog selection per the §6.4 decision (framework change in its own
      commit, with framework tests and README, if (a)).
- [ ] `ROUTES` with achievement gates; `WALKERS` as `characters`.
- [ ] Achievements (§9.1): all nineteen keys, each reachable with assists.
- [ ] `tools/capture_art.gd` — route stills to `assets/levels/`.
- [ ] **Exit:** every route, dog and walker is reachable from a fresh profile
      through its gate.

## Milestone 8 — Extras (§7)

- [ ] `walk/replay.gd` — input log + seed → re-sim; 8 s state ring buffer.
- [ ] Fail replay: last 3 s at half speed, best camera, skippable, Restart from
      the replay; reduced motion plays it at normal speed or as a still.
- [ ] `ui/photo_mode.tscn` — freeze, scrub, four cameras, zoom, narrator
      caption, Peak Flail suggestion, snap through `share_art.tscn` (the image
      in `configure`'s dictionary).
- [ ] `walk/narrator.gd` — event → line banks, priority, 8 s cooldown, no
      repeats, never over a telegraph; captions always.
- [ ] `walk/best_walks.gd` — top 10 per route + daily, Classic/Assisted tabs,
      `user://capitans_walk.cfg` merged, never regressing.
- [ ] Daily walk: date seed, route/dog/walker/modifier, ignores gates, streak.
- [ ] `ui/best_walks_panel.tscn` in the results flow.
- [ ] `tests/best_walks_test.gd`, `tests/narrator_test.gd`; extend
      `determinism_test.gd` for replay re-sim.

## Milestone 9 — Shell features (§7.9, §9)

- [ ] Pass the leash: `supports_multiplayer`, `local_multiplayer_turns`,
      `max_local_players` (per §16.5), same route and seed for every turn,
      a card with name, colour and P1/P2/P3, results after the last turn, one
      shared payout.
- [ ] `character_preview.tscn` — walker and dog on the setup plinth.
- [ ] Store (§9.2): Biscuits, eight slots (collar always filled, with the free
      plain red collar as the default), starter catalogue including six collars,
      `store_preview.tscn` covering both Capitan and the walker.
- [ ] Gallery (§9.3): dogs, walkers, Capitan's reactions, bosses, dioramas
      (including his bed from `capitans.jpg`); `gallery_stage.tscn` with
      `configure`, `set_view`, `set_auto_spin`.
- [ ] Share cards (§9.4): the results card and the photo card.
- [ ] `GameTheme` (§8.3) + `assets/game-icon.png` captured from the model.
- [ ] `intro.tscn` — five story cards (§1).
- [ ] Instructions copy and the first-run leash lesson (stand, step, lean),
      offering Easy legs after three falls before 3 m.
- [ ] Capitan's real barks (blocked on §16.2); narrator voice-over (§16.4).
- [ ] Credits, including Capitan and his owner.
- [ ] Tutorial video + poster (`tools/tutorial_driver.gd`, `record_tutorials.ps1`).

## Milestone 10 — Polish and integration (§12, §14)

- [ ] Accessibility sweep against §9.5.
- [ ] Mobile touch pass (pad layouts, left- and right-handed); web pass (120 Hz
      accumulator, `user://` persistence).
- [ ] `project.godot`: `config/name.capitans_walk`,
      `custom_user_dir_name.capitans_walk` (after the title is fixed),
      `config/icon.capitans_walk`, `dcs/build/single_game_id.capitans_walk`,
      `[share] stats_urls/capitans_walk` (≤ 42 bytes).
- [ ] `export_presets.cfg`: a standalone preset; exclude `games/capitans_walk/*`
      from other presets; keep `tools/` and `reference/` out.
- [ ] A remote for this repository → `.gitmodules` + gitlink (two commits).
- [ ] Root `AGENTS.md`: games table, submodules, options files, test table,
      feature tags, blurb. Update `godot-base/README.md` if it lists games.
- [ ] Write the folder `README.md` properly.
- [ ] **Exit:** all framework suites + all game suites exit 0 with
      `--game=all`; window suites run without `--headless`.

## Stretch (§15)

- [ ] Ghost of your best walk
- [ ] Online leaderboard (backend, privacy copy, input-log verification)
- [ ] More routes (rainy night, the vet's)
- [ ] Co-op walk: two leashes, one dog each
- [ ] Spanish localisation
- [ ] "Capitan walks you" mode
