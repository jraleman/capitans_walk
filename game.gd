extends RefCounted

## A solo first-person dog-guidance game, discovered without framework branches.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")


## Unbuilt features stay undeclared, so the shell never advertises empty experiences.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Capitan's Walk"
	game.tagline = "One dog. One path. Keep him on track."
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
	game.tutorial_video_path = "res://games/capitans_walk/assets/video/first_person.ogv"
	game.tutorial_poster_path = "res://games/capitans_walk/assets/video/first_person_poster.webp"
	game.stats_url = "https://deskcansaw.com"
	game.theme = GameTheme.studio_default()
	game.theme.cover_texture_path = "res://games/capitans_walk/assets/cover.png"
	game.copy = {
		"single_player_description": "Guide Capitan along a 200 m first-person Park walk.",
		"player_one_control_description": (
			"Walking is automatic. Steer the leash left or right to keep Capitan "
			+ "between the path edges. Whistle to recall him."
		),
		"instructions_headline": "KEEP CAPITAN ON THE PATH",
		"instructions_solo_summary": "Reach the 200 m finish with points remaining.",
		"instructions_rules": (
			"You see the walk through the human's eyes in an original low-poly 3D Park. "
			+ "Forward walking is automatic: concentrate on Capitan and the visible red leash. "
			+ "Steer left or right to move your leash hand, not teleport the dog. "
			+ "Equal opposing inputs cancel; releasing returns your hand toward the centre.\n"
			+ "The cream edges mark the designated path. Capitan's centre must stay "
			+ "between them. Start with 100 points and earn one point for each metre "
			+ "you advance while he is on the path.\n"
			+ "Each excursion has a one-second grace period. After one continuous second "
			+ "outside, lose ten points per second until Capitan returns. "
			+ "The OFF PATH caption shows grace time or the active penalty. "
			+ "Returning stops the penalty immediately and resets the grace period.\n"
			+ "Squirrels, pigeons and friendly dogs tempt him toward the grass. "
			+ "Each distraction shows its side and a warning before pulling. "
			+ "Counter-steer or Whistle; the leash applies real equal and opposite forces.\n"
			+ "Whistle recalls him after 0.3 seconds, with a six-second cooldown. "
			+ "Release before calling again. The dog never runs away or drops the leash.\n"
			+ "Reach the finish at 200 m with points remaining to win. Zero points "
			+ "ends the game; human falls and balance no longer end this walk. "
			+ "Results separate distance, remaining points and off-path deductions.\n"
			+ "Restart immediately repeats the same Park seed with 100 points. "
			+ "Walk speed and Long warnings are live assists; Reduced motion keeps "
			+ "the camera steady and parks decorative dog animation. "
			+ "This playable art pass is not Capitan's verified final likeness."
		),
		"instructions_player_one_controls": (
			"Steer leash left/right, Whistle and Restart. Walking is automatic. "
			+ "Keyboard controls are rebindable below. Escape pauses.\n"
			+ "Fixed gamepad: left stick or D-pad left/right steer the leash, "
			+ "A whistles, Y or Back restarts, Start pauses. Stick steering is analogue.\n"
			+ "Touch: independent left/right steering pads, Whistle, Restart and Pause. "
			+ "Game settings offer Thumbs, Left-handed and Right-handed layouts. "
			+ "Help only hides key legends, never the active touch controls or warnings."
		),
		"instructions_demo_prompt": "THE FIRST-PERSON PARK WALK",
	}
	return game
