# Capitan's Walk — Game Design Document

> Hand-off document for the implementation session. It fixes the concept, the
> rules, the architecture and the order of work. Numbers marked *(tune)* are
> starting points, not contracts. Read the repository's `AGENTS.md` first — the
> framework/game boundary there overrides anything here that seems to conflict.
> Capitan is a **real dog**. His look is taken from the owner's reference,
> `capitans.jpg` (§6.1). Anything marked *(verify)* must be checked with the
> owner before it reaches a model, a texture or player-facing copy (§16).

| | |
| --- | --- |
| Game ID | `capitans_walk` |
| Title | Capitan's Walk *(working title — §16)* |
| Folder | `godot-base/games/capitans_walk/` (its own Git repository, intended to become a submodule) |
| Control style | `GameManifest.CONTROL_STYLE_CUSTOM_KEYS` |
| Round rules | Game-owned (`uses_shell_round_rules = false`) |
| Players | Solo; two- or three-human hot seat, "Pass the leash" (`max_local_players = 3`, turns) |
| Menu order | `11` (after Sailor Man's planned `10`) |
| Feature tag | `capitans_walk` |
| Physics reference | `games/cube_trials/` (node-free fixed-step model under a real 3D view) |
| Look-and-feel reference | `games/cube_trials/`, `games/chicken_pit/` (toy-like 3D in a `SubViewport` under the 2D shell) |
| Renderer | `gl_compatibility` — unchanged |

---

## 1. Concept

**Capitan** loves his walk more than anything in the world. He loves squirrels,
hydrants, pigeons, every smell on the pavement and everyone he meets. He also
loves you, the person at the other end of the leash. You have two legs that
answer to four keys and very little balance.

**Capitan's Walk** is a QWOP-style physics comedy about walking a dog. You
drive a clumsy human's thighs and calves one key at a time along a narrow,
rail-like path: a curb, a boardwalk plank, the painted edge of a bike lane, a
snowy ridge. Capitan trots ahead on the leash and pulls wherever his heart
goes. If you fall over or drift off the path, the walk ends. The goal is to go
as far as you can while keeping Capitan happy. Then you laugh at the replay
and press restart.

### Locked pillars

1. **The fall is the punchline, not the punishment.** Every walk ends in a fall,
   so falling must be funny, fast and fair. The replay is ready the instant you
   land, and restart takes under two seconds.
2. **Honest, deterministic physics.** The walker, the leash and Capitan are a
   node-free fixed-step model at 120 Hz, seeded per walk. The same seed and the
   same inputs always produce the same walk. That gives exact replays, photo
   mode, fair daily challenges and testable physics.
3. **Capitan is a character, never a hazard.** He always loves you. Every pull
   has a reason the player can see, and every distraction is **telegraphed**
   before it pulls. The comedy comes from his enthusiasm, never from cruelty to
   the dog or by the dog.
4. **The leash is a tool.** A beginner fights the pull. An expert leans into it
   and uses Capitan as a kite anchor. The skill ceiling is learning to use
   his pull to stay upright (§4.4).
5. **Hard to master, but everyone can play.** Classic QWOP is famously cruel.
   Assists (§3.5) let anyone walk Capitan, and they never block an achievement.
6. **Same studio look as Cube Trials.** A real, toy-like 3D world in an isolated
   viewport, filmed from the side and driven by a node-free 2D model, under the
   shared HUD.

### Look and tone

The look is goofy, warm and a little miniature, like a tabletop neighbourhood
of painted wood and felt. The walker is a soft, bendy toy figure with big shoes. Capitan
bounces when he trots, his ears flip up at a squirrel, and his whole back
end wags. A **dramatic narrator** (§7.4) treats each walk like a nature
documentary crossed with a sports final. The humour is affectionate. Nobody
gets hurt: a fall is a floppy tumble, a puff of leaves and a narrator who
cannot believe what they have just seen.

### Story (for the intro cards and `instructions_rules`)

Five short cards, using the same intro shape as the other games:

1. Every morning at seven, Capitan sits by the door. He has been sitting there
   since quarter past six.
2. The leash comes off the hook. Somewhere, a squirrel feels a chill.
3. Outside there are hydrants, pigeons, puddles and one very small, very angry
   chihuahua.
4. You have two legs, one leash and absolutely no balance.
5. He is so ready. — **Walkies!**

---

## 2. Core loop

```
Title ─► Play ─► Mode select (Solo / Pass the leash · route · walker + dog on the plinth)
     ─► Instructions ─► (first time only) Leash lesson: stand, step, lean into a pull
     ─► WALK: 3-2-1 off the porch
            stride ─► Capitan trots ─► a distraction telegraphs ─► brace or stop
            ─► sniff spot: stand still, happiness fills ─► hazard ─► surprise event
            ─► every 250 m (tune): a boss set piece
        ─► FALL or OFF THE PATH ─► instant replay (skippable) ─► results
            (distance, Capitan's verdict, best combo, cause of the fall)
     ─► Biscuits payout ─► best-walks table ─► Restart (one key)
     ─► Photo mode / Share card / Store / Gallery
```

A beginner's walk lasts **20–90 seconds**. A practised walk can last
**3–6 minutes**. Restart is the most-pressed button in the game, so it costs
one key and no menu.

---

## 3. The walker — QWOP physics

### 3.1 Body model — `walk/walker_body.gd`

The walker is a **position-based (Verlet) ragdoll** in the sagittal (side)
plane. It is `RefCounted` and touches no node or autoload. It steps at a fixed
**120 Hz** *(tune)*, like Cube Trials' `trial_state.gd`. Godot's physics
server is deliberately **not** used: it is neither deterministic across
platforms nor importable by headless tests.

| Part | Particles | Notes |
| --- | --- | --- |
| Head | 1 | Rigid on the neck; a head contact is a fall |
| Torso | neck, hip | The torso angle is the main balance readout |
| Legs (×2) | knee, ankle, toe | Thigh = hip→knee, calf = knee→ankle, foot = ankle→toe |
| Leash arm | hand | A soft spring from the shoulder; it carries the leash force into the torso (§4.4) |

Distance constraints hold the bones. Angular limits stop knees bending
forwards and hips folding unnaturally. **Joint motors** are angular springs
toward a target angle with a stiffness and damping per joint. Default body: 1.75 m, 70 kg,
hip height 0.92 m *(tune)*. Walker profiles (§6.3) change the dimensions and
motor strengths, **never the solver**.

Contacts: toes, ankles, knees, hip, neck and head collide with the route's
ground polyline. Friction comes from the surface (§5.3). Cosmetic shoes
change nothing (§9.2).

### 3.2 The four keys

| Action | Key | Gamepad | Touch | Effect |
| --- | --- | --- | --- | --- |
| Thighs A | **Q** | LB | Top-left pad | Left thigh forward, right thigh back |
| Thighs B | **W** | LT (analogue) | Bottom-left pad | Right thigh forward, left thigh back |
| Calves A | **O** | RB | Top-right pad | Left knee bends, right knee straightens |
| Calves B | **P** | RT (analogue) | Bottom-right pad | Right knee bends, left knee straightens |
| Whistle | Space | A | Pad above the leash icon | Call Capitan to heel (§4.5) |
| Restart | R | Y / Back | Restart button | Instant new walk on the same route |
| Photo | F | X (after a fall) | Camera icon | Photo mode (§7.3) |
| Pause | Escape (shell) | Start | Pause icon | — |

Opposing keys held together cancel each other. The analogue triggers scale motor strength
from 0 to 1, so a pad player can feather a step. Touch uses **independent
multitouch contacts**, one per pad, as Cube Trials' `drive_controls.gd` does.

**No input does not mean collapse.** With no key held, the joints relax toward
a neutral standing pose with modest stiffness *(tune)*. On flat ground and
with a slack leash the walker **can stand still indefinitely**. That is
essential, because standing still is how you let Capitan sniff (§4.3). A
strong pull will still topple a relaxed walker.

### 3.3 Balance and the path — the lateral axis

The path is narrow, **0.6 m** *(tune)*, and the camera sits slightly above
it (§8.1), so drift is visible. On top of the side-plane ragdoll, the model
keeps one **lateral sway** value `z` for the body's centre of mass, as an
inverted pendulum:

```
z'' = (g / h_com) · z − k_stance · (z − z_feet) + F_leash_z / m + F_events_z / m
```

- `k_stance` is strong in double stance, weak in single stance and zero in
  the air. **Standing still recentres you; flailing does not.**
- When a foot plants, it lands at the current `z` plus a small catch-step
  toward the centre. A sideways pull while you stride therefore **accumulates**
  as drift.
- Capitan trots along the path's centre line, so a slack-to-taut leash usually
  pulls you **back toward the centre**. Distractions pull you off it (§4.2).

The player has no sideways key. Lateral control comes from **timing**: stop to
steady yourself, or let the leash steer. This is the riskiest rule in the
game. Milestone 1 must prove it feels fair (§15).

A HUD **balance bubble** (a spirit level) shows `z` against the path edges as
a number, a position and an icon, so it never relies on colour alone.

### 3.4 How a walk ends

| End | Rule *(tune)* | Narrator flavour |
| --- | --- | --- |
| **Fall** | The head or neck touches the ground, or the torso stays past 80° from upright for 0.5 s | "And down… goes… the human." |
| **Off the path** | The centre of mass passes the path edge (`abs(z) > half_width + 0.1 m`) | The route's own: hedge, sand, snowbank, puddle |
| **Wound up** | The leash wraps both legs three times (chihuahua boss, §5.5) | "Gift-wrapped. By a dog." |

Knees on the ground are **not** a fall. The classic QWOP knee-scoot is
legal, just slow, and it breaks the combo (§7.5). One fall ends the walk. There
are no lives. The shell round is one walk.

**Distance** is the furthest hip position reached, in metres, shown to one
decimal. It is the headline number and the leaderboard key (§7.2).

### 3.5 Assists

| Assist | What it does |
| --- | --- |
| **Easy legs** | Two keys (left leg / right leg) play an authored stride macro on the four motors. You still choose *when* to step, and you still balance, brace and stop |
| **Steady** | 0–100 % of an extra upright spring on the torso |
| **Walk speed** | Simulation at 100 / 85 / 70 % |
| **Long warnings** | Doubles every distraction telegraph (§4.2) |

Assisted walks are stored with an **assist badge** and listed on their own tab
of the best-walks table (§7.2). They earn every achievement and Biscuits
normally. Assists must never make the game *worse*. `walk_state_test.gd` pins
that a scripted Easy-legs gait walks at least as far as the same gait on four
keys.

---

## 4. Capitan — the dog and the leash

### 4.1 The leash — `walk/leash.gd`

The leash is a **spring-damper rope** from the walker's hand to Capitan's
collar: 1.8 m long, with 0.3 m of slack *(tune)*, and per-breed lengths (§6.2).
When slack, it exerts nothing. When taut, its force grows with the
stretch and is clamped. The **view** draws it as a sagging curve, but the model
needs only its endpoints and tension. It has an `(x, z)` direction: forward or back
along the path, and sideways across it.

The leash is looped on the wrist. Capitan **never** runs away, and the walk never
ends because the leash was dropped.

### 4.2 Moods and distractions — `walk/dog_brain.gd`

Capitan trots ahead and tries to keep the leash just taut. That is the
*gentle pull* a good walker learns to lean on. A distraction overrides this:

| Distraction | Pull shape | Telegraph (0.6–1.0 s, tune) | Counter |
| --- | --- | --- | --- |
| **Squirrel** | **Sudden lunge**: a sharp forward-sideways impulse, 0.4 s | Ears up, freeze, "!" bubble, squirrel on a tree | Plant both feet and lean back |
| **Hydrant** | **Slow drag** sideways to the hydrant, then a sniff stop | Nose down, tail slows, hydrant icon | Stop and let him sniff (§4.3), or brace |
| **Pigeon** | **Zigzag**: alternating sideways tugs, 3–5 beats | Head bobbing in time with the pigeon | Stand still; time strides between tugs |
| **Food smell** | **Long steady drag** forward or back, nose to the ground | Sniffing particles, nose twitch | Lean against it; walk with it if it's forward |
| **Sit-down protest** | **Anchor**: he sits, the leash goes rigid behind you | He looks at you over his shoulder, then sits | Stop and wait 2 s; pulling makes it longer |

Every telegraph carries a **caption, an icon and a sound** ("Capitan spots a
SQUIRREL!"). None relies on colour or on sound alone. The brain is seeded,
and distraction frequency depends on distance, breed (§6.2) and happiness
(§4.3).

### 4.3 Happiness

A 0–100 meter *(tune)*, drawn as a bone with a tail-wag icon and a number.
It starts at 60.

| Fills | Drains |
| --- | --- |
| Standing still at a **sniff spot** while he sniffs: +4/s | Time walking without a sniff: −1/s after 20 s |
| A sniff spot is marked by a ring of grass; it is "safe", with no hazard within 6 m | Whistling him off a sniff (§4.5): −10 |
| Treats (§7.1): +15 | Pulling him out of a sit-down protest: −15 |
| Letting an event play out (§5.4): +10–25 | A near-fall that yanks him: −5 |
| A perfect-rhythm combo of 5+ strides: +1 per stride | |

Happiness changes the walk:

- **Pull strength:** ×0.7 at 100 → ×1.5 at 0. Ignoring him makes him pull harder.
- **Distraction rate:** lower when he is happy.
- **Score multiplier:** ×1.0 at 0 → ×2.0 at 100 (§7.6).

Happiness never ends a walk. At 0, Capitan is not sad. He is *determined*.

### 4.4 Leaning into the pull — the skill ceiling

The leash force reaches the hand, and the arm spring carries it into the
torso at shoulder height. When you lean back against a taut forward pull, the
pull creates a **restoring torque**. The tuning target: a steady trot pull holds
a walker leaning 8° back *(tune)*, which is the posture that walks fastest. Lunges
are survivable from that same lean if both feet are down. A sideways pull is
dangerous from a stride and harmless from double stance.

The leash lesson (§2) teaches this in three prompts: stand, step, and lean into
the pull. The `capitans_walk_kite` achievement rewards it (§9.1).

### 4.5 The whistle

Space calls Capitan to heel. It **ends the current distraction early** after
0.3 s, and Capitan trots back to the centre line, which pulls you toward the
centre too. It costs happiness if it interrupts a sniff, and it has a 6 s
cooldown *(tune)*. It is the panic button that trades his joy for your balance. A walk
with no whistle is its own achievement.

---

## 5. Routes

### 5.1 Generation — `walk/route_generator.gd`

A route is **endless**. It is built from **hand-authored chunks**, 8–20 m
each, picked by a seeded generator from that route's pool. Chunks are validated
by tests, never generated from free noise. Each chunk declares its length,
its ground profile (flat, slope, steps and gaps under 0.25 m), surfaces, sniff
spots, item slots, hazard slots and a difficulty tier. The generator obeys these rules:

- There is at least one sniff spot every 40 m *(tune)*.
- No hazard sits within 3 m of the previous one at tier 1, shrinking with distance.
- Difficulty tiers rise with distance: tier 1 to 50 m, tier 2 to 150 m, tier 3 beyond *(tune)*.
- **Set pieces** come at fixed distances: a surprise event roughly every 120 m
  and a **boss** at 250 m and every 250 m after it *(tune)*.
- The same seed always produces the same route. The daily challenge uses this (§7.2).

### 5.2 The routes (shared level selector)

Use the manifest's `levels` with achievement gates, like Cube Trials. Each
route has an `icon` captured from the real scene by `tools/capture_art.gd`.

| # | Route | The path | Signature hazards | Signature event | Boss | Unlocked by |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **The Park** | Garden-bed edging along the lawn | Puddles, sprinklers, joggers, pigeons | Cat showdown | **Chalupa**, the chihuahua | always |
| 2 | **Beach Boardwalk** | One plank wide, sand either side | Banana peels, seagulls, skateboarders, wet planks | Dropped hot dog | **The Seagull Gang** | `capitans_walk_park_50` |
| 3 | **City Rush Hour** | The curb | Commuter crowds, skateboarders, food carts, manhole steam | Sudden rainstorm | **The Crosswalk** | `capitans_walk_beach_50` |
| 4 | **Snowy Hill** | A packed ridge trail, up and down | Ice (low friction), sledders, snowballs | Snowball ambush | **The Snowplough** | `capitans_walk_city_50` |
| 5 | **Fairground** | A plank walkway over the mud, at night | Spilled popcorn, balloons, a mascot, other dogs | Prize-stall goldfish | **The Marching Band** | `capitans_walk_snow_50` |

Unlock distances are **50 m** *(tune after the Milestone 1 playtest)*. In
QWOP, 100 m is a famous feat. The unlock should be a proud moment, not a
wall.

### 5.3 Hazards — `walk/hazards.gd`

| Hazard | Effect on the model | Telegraph |
| --- | --- | --- |
| **Puddle** | Ground friction 0.3 for its width, plus a splash; Capitan *loves* puddles | Reflective patch, ripple |
| **Banana peel** | Friction ≈ 0.05 under one foot for 0.5 s | Bright peel on the path, sitting a beat ahead |
| **Sprinkler** | A timed sideways push in an arc; Capitan wants to play in it (a sniff-spot chance if you stop) | It ticks before it sweeps |
| **Skateboarder** | Passes from behind; it bumps you only if you are mid-stride when it passes | A rumble and a bell 2 s ahead, with a caption |
| **Jogger** | Passes from the front; Capitan wants to follow (a short backward drag) | A jogger approaching, footsteps |
| **Other dog** | Capitan greets it: a sniff-spot chance, or a tug if you keep walking | The dog appears, with a tail-wag exchange |
| **Ice / wet plank** | Friction 0.15–0.4 over a whole chunk | Surface sheen and an icon on the balance bubble |
| **Slope** | Gravity along the path; a steep downhill speeds you and Capitan up | Visible ground profile |

### 5.4 Surprise events — `walk/events.gd`

Short scripted set pieces of 5–15 s *(tune)*. Each one has a **choice that
trades safety for happiness**:

- **Cat showdown.** A cat on a wall. Capitan freezes, then lunges. Stand still through the
  stare-down (3 s): the cat leaves, Capitan is proud, happiness +20. Walk on and he
  lunges twice.
- **Dropped hot dog.** It lands just off the path. Capitan drags toward it. Let him reach it,
  standing close to the edge: happiness +25 and a triumph pose. Whistle him off
  and he begins a sit-down protest.
- **Sudden rainstorm.** For 20–40 s, puddles spawn and every surface's
  friction drops by a third. Capitan stops to **shake**, giving a sideways jiggle
  on the leash. The narrator panics.
- Each route adds its own: the snowball ambush, the prize-stall goldfish and
  others (§5.2).

### 5.5 Bosses

A boss is a **set-piece chunk**, 15–30 m long, with readable patterns. You beat it
by walking past it without falling. Beating it pays a treat shower and an
achievement.

| Boss | Pattern |
| --- | --- |
| **Chalupa** (Park) | A tiny, extremely angry chihuahua barks in rhythms. Barks 1–2 trigger Capitan's flinch-pulls. Bark 3 is a charge: she circles, Capitan circles to hide behind your legs, and the **leash wraps your legs**. Step over the wrap (a high-thigh step on the right beat) to unwind it. Three wraps and you are gift-wrapped (§3.4). She is an original character, **not** Dulce from Dulce's Adventure. |
| **The Seagull Gang** (Beach) | Three gulls dive for your sandwich in turn: sideways tugs as Capitan defends you |
| **The Crosswalk** (City) | A countdown walk-light. Cross before it turns, among commuters who part only for a steady walker |
| **The Snowplough** (Snowy) | A plough pushes a wave of snow down the hill. Keep walking uphill ahead of it, braced against the sideways spray |
| **The Marching Band** (Fairground) | The band's beat drives the pulls: Capitan marches in time. Stride on the beat for a rhythm bonus |

---

## 6. Characters

### 6.1 Capitan

The star of the game and the default dog. The owner's reference is
`capitans.jpg` in this folder, an illustration of Capitan lying on his dog
bed. Model him from it:

| Feature | From the reference |
| --- | --- |
| Coat | **Tricolour**: mostly white body, chest, legs and paws; a scruffy, wiry, slightly long coat with tufts at the cheeks, elbows and legs |
| Head | Black on both sides of the head and over the ears, split by a **white blaze** that runs from the forehead down the muzzle |
| Tan points | A **tan "eyebrow" spot** above each eye, and tan at the cheeks and the corners of the mouth |
| Ears | Black, soft and **floppy**, hanging to the jaw. Telegraph poses lift them halfway rather than pricking them up |
| Face | Big, round, dark eyes with bright highlights, a black nose, a whiskery beard on the muzzle and a pink tongue out in a wide happy grin. This is his default expression |
| Tail | White and plumed, carried **curled up over the back**. The happiness wag (§8.2) drives it |
| Build | **Small-to-medium**, compact, with sturdy white legs and big soft paws. About 40 cm at the shoulder for the model *(tune)* |
| Breed | A **terrier-type mix**. Copy calls him exactly that and names no specific breed |
| Collar | None in the reference. His collar is a **store item** (§9.2): a plain red one is free and worn by default, so the leash always has somewhere to clip |

The illustration's style exaggerates the head and eyes. Keep that charm, but
check the head-to-body ratio against a photo before final modelling *(verify)*.
The dog bed, with its chewed corner, is a good home-scene prop for intro card 1
and a gallery diorama.

Personality: endlessly enthusiastic, very social, loves smells more than
walking. He has a balanced distraction table and a medium pull. If the owner can record
**his real barks, huffs and happy noises**, the game uses them as his voice
(§9.6).

### 6.2 Dogs — profiles in `walk/dog_profiles.gd`

A breed changes **the dog's** parameters: pull strength, leash length,
telegraph time, distraction weights and happiness rates. It never changes
the walker or the solver.

| Id | Name | Breed | Personality | Pull profile | Unlocked by |
| --- | --- | --- | --- | --- | --- |
| `dog_capitan` | Capitan | Terrier-type mix, small to medium | Enthusiastic, unpredictable | Balanced | always |
| `dog_waffles` | Waffles | Bulldog | Lazy, food-driven | Weak pull, short leash, frequent sit-down protests and food drags | `capitans_walk_hot_dog` |
| `dog_zippy` | Zippy | Terrier: tiny, smooth-coated and leggy, so her silhouette never reads as scruffy Capitan's | Hyper | Many small lunges and zigzags, short telegraphs (0.5 s) | `capitans_walk_chihuahua` |
| `dog_duchess` | Duchess | Great Dane | A gentle giant | Rare but enormous pulls, long leash; she can tow you, and steady you a lot | `capitans_walk_kite` |

### 6.3 Walkers — `characters`, profiles in `walk/walker_profiles.gd`

A walker changes **authored dimensions and motor strengths**, as Cube Trials'
vehicle profiles do, never the solver.

| Id | Name | Quirk | Unlocked by |
| --- | --- | --- | --- |
| `walker_sam` | Sam | The regular human: average everything | always |
| `walker_rosa` | Grandma Rosa | Short and wide-stanced, with **a cane** as a third contact point that plants on its own. Slow, weak motors, nearly unfallable, unbothered by Capitan | `capitans_walk_first_steps` |
| `walker_stretch` | Stretch | Very tall and long-legged with a high centre of mass: huge strides, huge wobble | `capitans_walk_park_50` |
| `walker_dash` | Dash | A sprinter: strong, fast motors, so it overshoots easily | `capitans_walk_best_in_show` |

Grandma Rosa unlocks after the first 10 m on purpose. The most forgiving walker
must not sit behind a skill wall.

### 6.4 One walker *and* one dog per seat

Setup must ask for **two** choices per seat. The framework's `characters` is
one list, so walkers use it and stand on the setup plinth with their dog beside
them. The dog choice needs one of these *(owner decision — §16)*:

- **(a) Recommended:** add a generic second per-seat list to `GameManifest`
  as **data** (for example `companions`, with the same id, title, icon and
  `requires_achievement` fields). Any future game with a pet, mount or
  sidekick can reuse it. This is a framework change, so it needs the framework
  tests and README updated in the same change.
- **(b)** Make the dog a choice-type tunable in `solo_setup_choices`. Tunables
  cannot be achievement-gated, so the game would have to fall back to Capitan
  for a locked dog. Hot seat would share one dog.

---

## 7. Fun extras

### 7.1 Treats and tennis balls

Items sit in chunk item slots on the path. Whoever reaches one first collects
it: Capitan's nose or the walker's body.

| Item | Effect *(tune)* |
| --- | --- |
| **Treat** | Happiness +15, plus points |
| **Treat bag** (rare) | **Calm mode**, 8 s: Capitan heels perfectly, with no distractions and a soft, steady pull |
| **Tennis ball** | **Super-steady steps**, 8 s: Capitan fixes on the ball in your hand and gives a perfect forward pull to lean on, and the torso gets a 50 % Steady assist |

Active power-ups show as a timer with an icon and a caption. They end with a
1 s warning.

### 7.2 Daily challenge and "best walks"

The leaderboard is **local only in v1**, with no backend.

- **Daily walk:** the seed is the player's local date (`YYYYMMDD`) *(§16)*. It
  picks a route, a dog, a walker and one modifier (rainy, windy, extra
  squirrels). Everyone gets the same walk on the same day, so share cards
  compare fairly. The daily walk ignores unlock gates, so a beginner can play
  the Fairground today. It records a best for the day and a streak.
- **Best walks:** the top 10 per route plus the daily walk. Each entry records distance,
  score, happiness, dog, walker, date, cause of the end and the assist badge.
  There are separate **Classic** and **Assisted** tabs. A screen in the game's
  results flow shows the table. It needs no framework change.
- Stored in `user://capitans_walk.cfg`, declared in `save_files` so the Saves
  screen backs it up. Writes merge into the file, and a record never
  regresses.

### 7.3 Photo mode

Determinism (§3.1) is what makes photo mode work. The model keeps a **ring
buffer of the last 8 s of state** *(tune)*, plus the walk's input log.

- After a fall, press **Photo** to freeze the world. Then scrub the last 8 s,
  choose a camera (side, close-up, low "dramatic", Capitan's-eye view), zoom,
  and pick a caption from the narrator's line for that fall, or none.
- The **Peak Flail** heuristic proposes a frame: the one with the highest
  combined limb angular speed while the head is lowest and the feet are highest.
  The player can always choose another.
- **Snap** renders the frozen view to an image and passes it to
  `ShareManager.generate_score_image()` through the game's `share_art.tscn`
  (`configure(Dictionary)` receives the image). The result is a share card
  framed like a photo, with the distance and a QR code (§9.4).
- With intense effects off there is no camera flash. With reduced motion the
  scrub is a slider and nothing animates between frames.

### 7.4 The narrator — `walk/narrator.gd`

The narrator is an over-the-top voice that is part nature documentary, part
sports final. `narrator.gd` is node-free. It maps **model events** (fall, lunge
survived, combo milestone, boss beaten, sniff granted, new best) to line banks,
with a priority, a cooldown (8 s, tune) and no repeat within a walk. Examples:

- *"The human attempts… a step. Bold. Foolish. Magnificent."*
- *"Capitan has seen a squirrel. Nothing else exists now."*
- *"Forty metres. Their ancestors would weep."*
- *"And the boardwalk claims another."*

Every line is a **caption**. Voice-over is optional *(owner decision — §16)*,
with a placeholder until it is recorded. The tunable offers Off, Captions or
Voice + captions, plus a Chattiness setting. The narrator never speaks over a
telegraph caption, because a telegraph is information and the narrator is
decoration.

### 7.5 Perfect rhythm combo

A **good stride** is a foot plant on the *other* foot, 0.45–0.9 s after the
previous one, with the torso within ±15° of upright *(tune)*. Consecutive good
strides build a combo:

| Strides | Tier | Multiplier |
| --- | --- | --- |
| 5 | **Strut** | ×1.5 |
| 12 | **Swagger** | ×2 |
| 25 | **Parade** | ×3 |
| 50 | **Best in Show** | ×4 |

A knee touch, two plants on the same foot or a torso past 30° breaks it. Combo
points are banked on each stride, so a fall doesn't erase them.

### 7.6 Scoring

```
walk score = Σ(stride points × combo multiplier) + treats + event bonuses + boss bonuses
final      = walk score × happiness multiplier at the end (×1.0–×2.0)
```

**Distance** ranks the best walks. **Score** pays Biscuits (§9.2). The
results panel shows both, plus **Capitan's verdict** (one to five tail wags,
from final happiness) and the **cause** ("Defeated by: a banana peel").

### 7.7 Fail replays

The instant a walk ends, a **replay** of the last 3 s plays at half speed from the
best camera, with the narrator's line. Any key skips it, and Restart restarts
straight from the replay. It is a re-simulation of the input log, so it is
exact. Reduced motion plays it at normal speed with a fixed camera, or offers a
still frame instead *(tunable: Replay — On / Still / Off)*.

### 7.8 Capitan's reactions (Gallery)

The Gallery (§9.3) shows Capitan in his signature poses, posed on the turntable
from the same `dog_rig.gd` the walk uses. A reaction joins the gallery when
the achievement for the moment that triggers it unlocks.

### 7.9 Pass the leash (hot seat)

Two or three players take **complete walks in turn** on the same route and seed,
in P1/P2/P3 order, as in Cube Trials. Each player picks a walker (and, with
§6.4 (a), a dog). A "Pass the leash" card between turns shows the next player's
name, colour **and** P1/P2/P3 label. The longest walk wins. Results wait for
the final turn, and one shared payout follows. Mobile stays single-player
(`GameSession.multiplayer_available()`).

---

## 8. Art direction

### 8.1 Pipeline and camera

Follow Cube Trials: a real `Node3D` world in an isolated `SubViewport` that the
node-free model drives, original vertex-coloured low-poly meshes, scenery batched
through `mesh_builder.gd` (copied from `cube_trials/world/`), a warm key light
with compatibility shadows, and no SSAO or glow. Budget: **below 60 draw calls** in
a walk shot, enforced by `walk_view_test.gd`.

The camera is a **2.5D side view**: perpendicular to the path, raised about
15° *(tune)*, so the path's width and the walker's sideways drift are visible
without a free camera. It frames the walker and Capitan with a little look-ahead.
Under reduced motion it follows smoothly, with no shake, punch or zoom.

### 8.2 Rigs

- **`walker_rig.gd`** — a soft toy figure with capsule limbs, big shoes and a
  readable silhouette at gameplay distance. Its bones copy the model's particles
  exactly, so the view never invents a pose the physics didn't make.
- **`dog_rig.gd`** — Capitan and the breeds come from one rig with per-breed
  proportions. The model drives the body's position. The view adds a
  procedural trot bounce, ear flips, a tail wag driven by happiness and the
  telegraph poses. These are decorative, and reduced motion calms them.
- **`leash_rope.gd`** — a sagging curve with the colour from the equipped leash
  (§9.2).
- Hat, scarf and shoe sockets on both rigs, plus a collar socket on the dog rig
  that the leash clips onto (§9.2).

### 8.3 Palette and theme

Warm morning colours, with Capitan's own coat as the base (`capitans.jpg`)
and the default red collar and leash as the accent *(tune)*:

```gdscript
const INK := Color("23252b")         # Capitan's black ears and head patches
const COAT := Color("faf6ef")        # his white coat
const TAN := Color("a8683a")         # his eyebrow and cheek points
const GRASS := Color("6fae4f")
const PAVEMENT := Color("c9c1b4")
const SKY := Color("bfe3f0")
const COLLAR := Color("e2553d")      # accent: the default leash and collar
const CREAM := Color("fdf5e6")
```

`GameTheme`: accent `COLLAR`, light `CREAM`, plaque `INK`, a morning-sky
gradient background, `style_share_card = true`, and the logo `assets/game-icon.png`
(Capitan mid-trot with a taut leash, captured from the model). Player identities
keep the shared blue/red/green colours, and the theme must not tint them.

---

## 9. Shell features

### 9.1 Achievements (keys are stable forever)

| Key | Title | Badge | Condition |
| --- | --- | --- | --- |
| `capitans_walk_first_steps` | First Steps | 10 M | Walk 10 m |
| `capitans_walk_park_50` | Around the Park | PARK | 50 m in the Park |
| `capitans_walk_beach_50` | Plank Walker | BEACH | 50 m on the Boardwalk |
| `capitans_walk_city_50` | Rush Hour Hero | CITY | 50 m in City Rush Hour |
| `capitans_walk_snow_50` | King of the Hill | SNOW | 50 m on Snowy Hill |
| `capitans_walk_fair_50` | Fairground Legend | FAIR | 50 m at the Fairground |
| `capitans_walk_chihuahua` | Small but Mighty | CHALUPA | Get past Chalupa |
| `capitans_walk_hot_dog` | Good Boy Gets a Treat | HOT DOG | Let Capitan get the dropped hot dog |
| `capitans_walk_cat_showdown` | The Stare-Down | CAT | Win the cat showdown |
| `capitans_walk_kite` | Lean On Me | KITE | Survive 5 lunges braced in one walk |
| `capitans_walk_best_in_show` | Best in Show | ×4 | Reach a 50-stride combo |
| `capitans_walk_happy_dog` | Happiest Dog Alive | 5 WAGS | End a 50 m+ walk with happiness ≥ 90 |
| `capitans_walk_knee_deep` | Knee Deep | SCOOT | Travel 10 m on your knees |
| `capitans_walk_no_whistle` | Free Spirit | NO WHISTLE | 100 m without whistling |
| `capitans_walk_rain_walker` | Singin' in the Rain | RAIN | Walk 30 m through a rainstorm |
| `capitans_walk_marathon` | Marathon Pup | 500 M | 500 m in one walk |
| `capitans_walk_daily` | Every Day Walkies | DAILY | Finish a daily walk |
| `capitans_walk_photographer` | Say Cheese | PHOTO | Snap a photo |
| `capitans_walk_pass_the_leash` | Pass the Leash | DUO | Finish a hot-seat walk |

These keys gate routes (§5.2), dogs (§6.2), walkers (§6.3), store items and gallery
exhibits. Every achievement can be earned with assists, on every walker.

### 9.2 Store — currency "Biscuits"

`store_currency`: about one Biscuit per 50 points *(tune)*, a small
`round_bonus`, **no `win_bonus`** (there is no CPU rival), and a ceiling of 150 per walk.
Everything is **cosmetic only**. Silly shoes do not change friction.

| Slot id | Wears | Kind |
| --- | --- | --- |
| `cw_dog_collar` | Capitan's collar | `collar` |
| `cw_dog_hat` | Capitan's hat | `hat` |
| `cw_dog_scarf` | Capitan's scarf/bandana | `scarf` |
| `cw_dog_shoes` | Capitan's booties | `shoes` |
| `cw_leash` | Leash colour | `leash` |
| `cw_walker_hat` | Walker's hat | `hat` |
| `cw_walker_scarf` | Walker's scarf | `scarf` |
| `cw_walker_shoes` | Walker's shoes | `shoes` |

Hats, scarves and shoes share a `kind` across both wearers, so a hat bought once can
go on Capitan **or** the walker. The rigs scale it. The collar slot has no
`empty_title`. The leash clips to the collar, so one is always worn, and the
free default fills it.

Starter catalogue:

- **Collars:** plain red (default, free); studded (punk); bow tie; flower
  crown collar; light-up LED (handy at the Fairground); and an anchor-tag
  sailor collar, a nod to his name, gated by `capitans_walk_happy_dog`.
- **Leashes:** red (default), rainbow, glow-in-the-dark and sausage-link.
- **Others:** a baseball cap,
a captain's hat (gated: `capitans_walk_marathon`), a party hat and a beanie; a
plaid scarf and a bandana; clown shoes, flippers, bunny slippers and rain
booties.

### 9.3 Gallery

`GALLERY_EXHIBITS`:

- **Dogs:** each dog, gated by its unlock.
- **Walkers:** each walker.
- **Capitan's reactions** (§7.8), gated by the moment's achievement: head tilt,
  squirrel freeze, sit-down protest, the hot-dog triumph, the rain shake, the cat
  stare-down and the zoomies.
- **Bosses:** Chalupa and the Seagull Gang.
- **Route dioramas:** one per route.

The stage implements `configure`, `set_view` and `set_auto_spin`.

### 9.4 Share card

There are two variants, both through the game's `share_art.tscn`:

- The **results card**: Capitan and the walker mid-stride, the distance as
  the headline, then happiness wags, best combo and the cause of the end.
- The **photo card** (§7.3): the player's frame, with the narrator caption
  as the headline.

Both carry the route, the daily badge where it applies, and the QR code to
`stats_url`.

### 9.5 Accessibility (non-negotiable)

- **Assists** (§3.5) are on the Game tab, and the leash lesson offers Easy legs after
  three falls before 3 m. It never forces them.
- **Telegraphs** carry a caption, an icon and a sound. The balance bubble and
  happiness meter show numbers and icons, never colour alone.
- **Captions** for every meaningful sound: barks, the skateboard rumble, the jogger,
  the sprinkler tick, Chalupa's bark rhythm (as a visual beat strip too), the band's
  beat and the walk-light countdown.
- **Long warnings** double every telegraph.
- **Reduced motion**: smooth follow camera, no shake or zoom punches, calmer
  decorative dog animation, replays at normal speed or as a still. The walker's
  flailing and Capitan's movement stay, because they *are* the gameplay.
- **Intense effects off**: no camera flash, no screen shake on a fall, and no
  rainstorm lightning flashes.
- **P1/P2/P3** labels on the pass-the-leash card and the HUD.
- Touch pads are large, can be repositioned for left- or right-handed play, and
  accept independent multitouch.

### 9.6 Audio — `audio/walk_audio.gd`

Footsteps per surface, the jingle of the collar and leash, squeaks, splashes
and boing-y falls. These are synthesised or recorded, original, game-owned and
short. Capitan's voice comes from **recordings of the real dog** where the owner can
provide them (§16), and from placeholders until then. Music is a light, bouncy
loop that ducks under telegraph sounds and narrator voice-over. Every sound
that carries meaning has a caption (§9.5).

---

## 10. Tunables and bindings

| Key | Type | Default |
| --- | --- | --- |
| `game/capitans_walk_easy_legs` | toggle | false |
| `game/capitans_walk_steady` | slider 0–100 % | 0 % |
| `game/capitans_walk_walk_speed` | choice: 100 / 85 / 70 % | 100 % |
| `game/capitans_walk_long_warnings` | toggle | false |
| `game/capitans_walk_narrator` | choice: Off / Captions / Voice + captions | Captions *(Voice + captions once recorded)* |
| `game/capitans_walk_narrator_chattiness` | choice: Quiet / Normal / Chatty | Normal |
| `game/capitans_walk_replay` | choice: On / Still / Off | On |
| `game/capitans_walk_touch_layout` | choice: Thumbs / Left-handed / Right-handed | Thumbs |

Bindings (§3.2) all use the prefix `controls/capitans_walk_`: `q`, `w`, `o`, `p`,
`whistle`, `restart`, `photo`, plus `easy_left` and `easy_right` (Easy legs).
The four leg keys are `movement: true`. In hot seat every seat shares P1's keys
(`local_multiplayer_turns`). The gamepad is polled in `gameplay.gd`, as Cube Trials
does.

---

## 11. Architecture

### 11.1 File layout

```
game.gd                        # GameManifest — copy, theme, achievements, credits
capitans_walk_options.gd       # constants-only: tunables, bindings, levels,
                               #   characters, store, gallery (loaded by path)
gameplay.gd / .tscn            # extends GameShell; inherited scene of game_shell.tscn
intro.tscn                     # five story cards (§1)
walk/input_frame.gd            # {q, w, o, p: 0..1, whistle: bool} — every source emits these
walk/walker_body.gd            # node-free Verlet ragdoll + lateral sway (§3)
walk/walker_profiles.gd        # Sam, Rosa (+cane), Stretch, Dash
walk/leash.gd                  # spring-damper rope (§4.1)
walk/dog_brain.gd              # trot, distractions, telegraphs, whistle (§4.2)
walk/dog_profiles.gd           # Capitan, Waffles, Zippy, Duchess
walk/walk_state.gd             # 120 Hz step: rules, distance, happiness, combo,
                               #   items, power-ups, end detection, score
walk/route_chunks.gd           # authored chunk data, per route
walk/route_generator.gd        # seeded, endless, rule-checked assembly (§5.1)
walk/hazards.gd                # surfaces and hazard behaviours
walk/events.gd                 # surprise events and bosses
walk/replay.gd                 # input log + seed → re-sim; state ring buffer
walk/narrator.gd               # event → line, priority, cooldown
walk/best_walks.gd             # table, daily seed, streak, cfg merge
input/key_source.gd            # keyboard + Easy legs macro
input/pad_source.gd            # gamepad, analogue triggers
input/touch_pads.gd            # four-pad multitouch (after drive_controls.gd)
world/walk_view.gd             # isolated SubViewport, 2.5D camera, photo cameras
world/walker_rig.gd
world/dog_rig.gd
world/leash_rope.gd
world/route_scenery.gd         # per-route props batched from chunk data
world/mesh_builder.gd          # copied from cube_trials/world/, adapted
ui/walk_hud.gd                 # distance, happiness bone, balance bubble, combo,
                               #   power-up timers, telegraph bubble
ui/leash_lesson.gd / .tscn     # first-run three-prompt lesson
ui/photo_mode.gd / .tscn
ui/best_walks_panel.gd / .tscn
audio/walk_audio.gd
assets/models/ assets/levels/ assets/icons/ assets/audio/ assets/video/
share_art.gd / .tscn           # results card and photo card
store_preview.gd / .tscn       # Capitan or the walker wearing one item
gallery_stage.gd / .tscn       # turntable
character_preview.gd / .tscn   # walker + dog on the setup plinth
tests/                         # §13
tools/                         # capture_art.gd, tutorial_driver.gd, chunk_preview.gd
README.md · DESIGN.md · TODO.md · AGENTS.md
```

### 11.2 Model / view split

Everything under `walk/` is `RefCounted`. It touches **no autoload and no node**,
and it is what the headless tests exercise. `gameplay.gd` collects one
`InputFrame` per tick from the active source, steps `walk_state.gd` at a
fixed 120 Hz with an accumulator, and hands the state to `walk_view.gd`. The
view may add bounce, wag and dust, but it never feeds back into the model. Replays, photo mode
and the daily walk all depend on that rule.

### 11.3 `GameShell` hooks used

`game_id`, `_prepare_session`, `_build_playfield`, `_load_round_settings`
(`super()`), `_reset_round_state`, `_activate_round`, `_update_round`,
`_handle_gameplay_input`, `_finish_round`, `_round_totals`, `_player_stats`,
`_describe_round_outcome`, `_round_highlight_summary`,
`_award_round_achievements`, `_round_points_earned`, `_configure_mode_ui`
(`super()`), `_on_game_setting_changed`, `_set_reduced_motion_enabled`
(**`super(value)`**), `_set_intense_effects_enabled` (**`super(value)`**).
Copy the signatures exactly from `AGENTS.md`.

A shell **round is one walk** in solo play and one full set of turns in hot seat.
With `uses_shell_round_rules = false`, the walk ends by its own rules (§3.4).
Gameplay then calls the shell's normal end-of-round path, as Cube Trials does.
**Restart** must reach a new walk in under 2 s, so it resets the model and the
view in place rather than reloading the scene. `_round_totals` reports
distance in centimetres as the integer score. `_player_stats` reports
distance, score, happiness, best combo, treats, cause of the end and the
assist badge.

### 11.4 Manifest sketch

```gdscript
game.id = Options.GAME_ID                       # "capitans_walk"
game.title = "Capitan's Walk"
game.tagline = "One dog. One leash. Zero balance."
game.menu_order = 11
game.gameplay_scene_path = "res://games/capitans_walk/gameplay.tscn"
game.intro_scene_path = "res://games/capitans_walk/intro.tscn"
game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
game.uses_shell_round_rules = false
game.supports_multiplayer = true                # pass the leash
game.supports_cpu_opponent = false
game.max_local_players = 3
game.local_multiplayer_turns = true
game.levels = Options.ROUTES                    # §5.2, achievement-gated
game.characters = Options.WALKERS               # §6.3; dogs per §6.4
game.character_preview_scene_path = ".../character_preview.tscn"
game.save_files = [{"path": "user://capitans_walk.cfg", "title": "Walk log",
		"description": "Best walks, daily streak and route records."}]
game.tunables / control_bindings / store_* / gallery_* = Options.*
game.tutorial_video_path / tutorial_poster_path
game.stats_url = "https://deskcansaw.com"       # ≤ 42 bytes
game.theme = theme                              # §8.3
```

---

## 12. Integration checklist (outside this folder)

- [ ] `project.godot`: `config/name.capitans_walk`,
      `config/custom_user_dir_name.capitans_walk="DeskCanSaw Games/Capitan's Walk"`
      (stable forever once shipped, so confirm the title and its spelling first),
      `config/icon.capitans_walk`, `dcs/build/single_game_id.capitans_walk`,
      `[share] stats_urls/capitans_walk`.
- [ ] `export_presets.cfg`: a standalone preset with the tag. Add
      `games/capitans_walk/*` to the other presets' `exclude_filter`, and keep
      `tools/` out.
- [ ] `.gitmodules` and gitlink once the folder has a remote (two commits).
- [ ] Root `AGENTS.md`: games table, submodule list, options-file list, test
      table, feature-tag list and a per-game blurb. Update `godot-base/README.md`
      if it lists games.
- [ ] If §6.4 (a) is chosen: `GameManifest` field, mode-select rows, framework
      tests and README, all in one framework change, with no game-name branch.
- [ ] Run `--import` after adding any `class_name`, and prefer preload-by-path.

---

## 13. Tests — `tests/`

These run headless unless noted. Each one is a standalone `SceneTree` script that exits 0.

| Suite | Covers |
| --- | --- |
| `walker_body_test.gd` | The neutral stance stands for 10 s on flat ground; a scripted four-key gait walks ≥ 10 m; fall and off-path detection; knee-scoot is not a fall; joint limits hold; every walker profile builds, and Rosa's cane plants |
| `determinism_test.gd` | The same seed + input log → identical state after 60 s, value for value; replay re-sim matches the live run; the ring buffer holds 8 s |
| `leash_test.gd` | Slack exerts nothing; the taut force is monotonic and clamped; leaning back on a steady pull holds 8°; a lateral pull recentres in double stance |
| `dog_brain_test.gd` | Every distraction is telegraphed for at least its minimum before force; the whistle ends one and respects its cooldown; breed profiles change only dog parameters; happiness scales the pull |
| `walk_state_test.gd` | Happiness fills and drains; the combo builds, breaks and banks; power-ups time out; scoring; cause of the end; Easy legs never walks shorter than four keys on the same gait |
| `route_generator_test.gd` | Every chunk in every pool is valid (continuous path, step ≤ 0.25 m, slots inside bounds); sniff-spot spacing; hazard spacing per tier; set pieces at their distances; the same seed gives the same route |
| `events_test.gd` | Every event and boss runs to completion under a scripted "stand still" input and a scripted "walk on" input, with the documented happiness outcome; Chalupa's wrap counts and unwinds |
| `best_walks_test.gd` | The daily seed is stable for a date and differs across dates; table order; Classic and Assisted tabs; cfg merge; records never regress |
| `narrator_test.gd` | Every model event has at least one line and a caption; cooldowns; no repeat within a walk; it never speaks over a telegraph |
| `capitans_scene_test.gd` | Gameplay loads under the shell; the HUD binds; pause; results; payout; Restart under 2 s; the pass-the-leash card |
| `walk_view_test.gd` *(window)* | Real render: walker, Capitan and the path edges in shot; the balance bubble readable; < 60 draw calls; portrait → ultrawide; touch pads clear of the walker |

The framework suites pick the game up automatically. Run them all with
`--game=all` before calling a milestone done.

---

## 14. Platforms

| Platform | Notes |
| --- | --- |
| Desktop | Primary target. Keyboard is the classic experience, and a gamepad adds analogue triggers |
| Mobile | Four-pad touch, Easy legs suggested on first run, single-player only (shell rule) |
| Web | The same build, a fixed 120 Hz step with an accumulator, and the local leaderboard in `user://` (IndexedDB) |

No gameplay script may branch on the platform. Differences are resolved where
input sources are built.

---

## 15. Milestones

1. **Physics spike.** ⚠ The riskiest part. `walker_body.gd`, the four keys and a debug 2D
   draw of the particles, with no art. Then the lateral axis and the path edges.
   *Goal: it is funny, learnable and fair.* At a playtest, a first-time
   player walks 5 m within 2 minutes, a practised player walks 50 m, and standing still
   is stable. Tune the 50 m unlock distance from these numbers.
2. **Leash and Capitan (grey box).** The rope, a basic trot and one distraction
   (the squirrel lunge). Prove that leaning into the pull works and feels
   learnable.
3. **The walk.** `walk_state.gd`: happiness, sniff spots, combo, ending,
   scoring, HUD, results, Restart under 2 s, Easy legs and the other assists.
4. **Routes.** Chunk format, generator and the Park chunk pool, with every hazard on the Park list.
5. **The 2.5D world.** View, camera, walker rig, dog rig, leash rope and Park
   scenery.
6. **Events and the first boss.** Cat showdown, hot dog, rainstorm, Chalupa.
7. **Content.** Routes 2–5 with their hazards, events and bosses; dogs; walkers;
   achievements; gated progression; captured route stills.
8. **Extras.** Replay, photo mode, narrator, best walks, daily walk.
9. **Shell features.** Pass the leash, store, gallery, share cards, character
   preview, intro, theme and icon, credits, tutorial video.
10. **Polish and integration.** Accessibility sweep, mobile touch pass, web pass,
    framework suites with `--game=all`, export preset and docs.

**Stretch:** a ghost of your best walk; an online leaderboard (needs a
backend, privacy copy and anti-cheat via input-log verification); more routes
(rainy night, the vet's); a co-op walk with two leashes, one dog each; Spanish
localisation; a "Capitan walks you" mode where the player is the dog.

---

## 16. Open questions for the owner

1. **Title and id.** "Capitan's Walk" or "Capitán's Walk"? The folder's
   `README.md` says `julios_walk`. Is that an old name? The title fixes
   `custom_user_dir_name` forever.
2. **Capitan's details.** Settled: his look (`capitans.jpg`), a small-to-medium
   terrier-type mix, and collars sold in the store (§6.1, §9.2). Still open:
   his signature habits, a photo to check the illustration's proportions, and
   whether the game can use **recordings of his real barks**.
3. **Picking the dog** (§6.4). Should `GameManifest` gain a generic per-seat
   companion list (a framework change, as data), or should the dog be a tunable?
4. **The narrator's voice.** Recorded voice-over in v1, or captions only until
   later? Who voices it?
5. **Pass the leash.** Is hot seat in v1, and with 2 or 3 seats?
6. **Boss roster and names.** Keep Chalupa (and is a chihuahua boss fine next to
   Dulce's Adventure, whose heroine is a chihuahua mix)? Are five bosses in v1 or
   two?
7. **Daily seed day boundary.** Local midnight (friendlier) or UTC (fair across
   time zones on a future online board)?
8. **Assisted walks.** Should they stay on their own leaderboard tab, or mix in
   with a badge only?
