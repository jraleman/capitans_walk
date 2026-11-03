extends RefCounted

## A solo physics prototype, discovered by the host without framework changes.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")


## Unbuilt features stay undeclared, so the shell never advertises empty experiences.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Capitan's Walk"
	game.tagline = "Four keys. One leash. A grey-box walk."
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
		"single_player_description": "Practice the leg motors, brace and Capitan's first lunge.",
		"player_one_control_description": (
			"Alternate thighs. Bend the swinging knee, then straighten it to plant. "
			+ "Plant both feet before a lunge. Whistle to recall Capitan."
		),
		"instructions_headline": "PLANT, STEP, BRACE",
		"instructions_solo_summary": "Dog + leash grey-box prototype. How far can you get?",
		"instructions_rules": (
			"This playable grey box adds Capitan's trot, a spring-damper leash, "
			+ "one squirrel lunge and Whistle. Final art and routes arrive later.\n"
			+ "Thighs A sends the left thigh forward and the right thigh back; "
			+ "Thighs B reverses them. Calves A bends the left knee and straightens "
			+ "the right; Calves B reverses them. Equal opposing controls cancel.\n"
			+ "Try bending the swinging leg, extending it to plant, then swapping legs. "
			+ "Release everything to stand and settle. Kneeling is legal.\n"
			+ "Capitan gently pulls toward the centre line. A ! and caption warn of "
			+ "his squirrel lunge: plant both feet. Thighs B + Calves B can help "
			+ "lean back against the pull instead of pitching forward.\n"
			+ "Whistle recalls him after 0.3 seconds, with a six-second cooldown. "
			+ "Release before calling again. The dog never runs away or drops the leash.\n"
			+ "The walk ends when your head or neck reaches the ground, "
			+ "you lean beyond 80 degrees for half a second, or sway off the path. "
			+ "The balance gauge shows both your sway and the edge.\n"
			+ "Distance is the furthest hip position, not a timer. Restart is immediate, "
			+ "even after a fall. Steady and Walk speed are available in Game settings."
		),
		"instructions_player_one_controls": (
			"Four independent leg motors, Whistle and instant Restart. "
			+ "Keyboard controls are rebindable below. Escape pauses."
		),
		"instructions_demo_prompt": "THE GREY-BOX WALK",
	}
	return game
