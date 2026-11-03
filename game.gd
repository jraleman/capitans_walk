extends RefCounted

## A solo physics prototype, discovered by the host without framework changes.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")


## Unbuilt features stay undeclared, so the shell never advertises empty experiences.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Capitan's Walk"
	game.tagline = "One leash. Five distractions. Find your rhythm."
	game.menu_order = 11
	game.gameplay_scene_path = "res://games/capitans_walk/gameplay.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.uses_shell_round_rules = false
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.levels = Options.ROUTES
	game.characters = Options.WALKERS
	game.tutorial_video_path = "res://games/capitans_walk/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/capitans_walk/assets/video/tutorial_poster.webp"
	game.stats_url = "https://deskcansaw.com"
	game.copy = {
		"single_player_description": "Walk, brace, sniff and find your rhythm in the grey box.",
		"player_one_control_description": (
			"Alternate thighs. Bend the swinging knee, then straighten it to plant. "
			+ "Plant both feet before a lunge. Whistle to recall Capitan."
		),
		"instructions_headline": "PLANT, STEP, BRACE",
		"instructions_solo_summary": "Seeded Park grey box. How far can you get?",
		"instructions_rules": (
			"This playable grey box has five dog moods, a spring-damper leash, "
			+ "sniffing, happiness and rhythm points on a seeded Park path. "
			+ "Sprinklers, joggers, pigeon flocks and friendly dogs bring physical choices. "
			+ "Final art and pickups arrive later.\n"
			+ "Thighs A sends the left thigh forward and the right thigh back; "
			+ "Thighs B reverses them. Calves A bends the left knee and straightens "
			+ "the right; Calves B reverses them. Equal opposing controls cancel.\n"
			+ "Try bending the swinging leg, extending it to plant, then swapping legs. "
			+ "Release everything to stand and settle. Kneeling is legal.\n"
			+ "Capitan gently pulls toward the centre line. A ! and caption warn of "
			+ "his squirrel lunge: plant both feet. Thighs B + Calves B can help "
			+ "lean back against the pull instead of pitching forward.\n"
			+ "H warns of a slow hydrant drag and sniff stop; V warns of pigeon zigzags; "
			+ "~ warns of a forward/back food drag; Z warns that Capitan will sit. "
			+ "Stop and wait two seconds through a protest. Pulling resets the wait.\n"
			+ "Grass rings mark safe sniff spots. Stop nearby to let Capitan sniff: "
			+ "+4 happiness per second. Happiness starts at 60; walking without "
			+ "a sniff drains it after twenty seconds. Lower happiness means more pull.\n"
			+ "Blue patches marked ~ PUDDLE lower foot grip to 0.30. "
			+ "^ SLOPE marks real terrain: gravity acts on both you and Capitan. "
			+ "Rings stay at least six metres clear of these hazards. "
			+ "Restart repeats the same Park seed.\n"
			+ "* Sprinklers tick before each sideways water sweep: plant both feet. "
			+ "J warns of an approaching jogger and a short backward drag. "
			+ "VV marks a pigeon flock with three sideways tug beats. "
			+ "D marks a friendly dog: stop and settle to greet, or brace against the tug. "
			+ "Stopping near a sprinkler can also let Capitan play and sniff. "
			+ "These opportunities are not the hazard-free grass rings.\n"
			+ "Whistle recalls him after 0.3 seconds, with a six-second cooldown. "
			+ "It cancels his interest in Park encounters, but cannot stop sprinkler water. "
			+ "Calling him off a sniff costs ten happiness. Release before calling again. "
			+ "The dog never runs away or drops the leash.\n"
			+ "Alternate foot plants 0.45-0.9 seconds apart while within 15 degrees "
			+ "of upright to build a rhythm combo. Knees, repeated feet or a lean "
			+ "past 30 degrees break it. Strut, Swagger, Parade and Best in Show "
			+ "bank multipliers; a fall never erases those points.\n"
			+ "The walk ends when your head or neck reaches the ground, "
			+ "you lean beyond 80 degrees for half a second, or sway off the path. "
			+ "The balance gauge shows both your sway and the edge.\n"
			+ "Distance is the furthest hip position, not a timer. Restart is immediate, "
			+ "even after a fall. Results also show points multiplied by final happiness "
			+ "and Capitan's one-to-five-wag verdict.\n"
			+ "Game settings offer Easy legs, Steady, Walk speed and Long warnings. "
			+ "Easy left/right play one motor stride per choice; both cancel, and "
			+ "release stops. The four manual motors still work for bracing."
		),
		"instructions_player_one_controls": (
			"Four independent leg motors, optional two-key Easy legs, Whistle and Restart. "
			+ "Keyboard controls are rebindable below. Escape pauses.\n"
			+ "Fixed gamepad: LB / LT thighs, RB / RT calves (analogue triggers), "
			+ "A whistle, Y or Back restart, Start pause. D-pad left / right selects "
			+ "Easy legs when enabled. Gamepad buttons are not rebindable.\n"
			+ "Touch: independent motor pads, Whistle, Restart and Pause. Game settings "
			+ "offer Thumbs, Left-handed and Right-handed layouts. Easy legs keeps "
			+ "Thighs B + Calves B available for manual bracing."
		),
		"instructions_demo_prompt": "THE GREY-BOX WALK",
	}
	return game
