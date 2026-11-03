extends RefCounted

## Stable, preload-safe data; only implemented prototype controls get Settings rows.

const GAME_ID := "capitans_walk"
const EASY_LEGS_KEY := "game/capitans_walk_easy_legs"
const STEADY_KEY := "game/capitans_walk_steady"
const WALK_SPEED_KEY := "game/capitans_walk_walk_speed"
const LONG_WARNINGS_KEY := "game/capitans_walk_long_warnings"
const NARRATOR_KEY := "game/capitans_walk_narrator"
const CHATTINESS_KEY := "game/capitans_walk_narrator_chattiness"
const REPLAY_KEY := "game/capitans_walk_replay"
const TOUCH_LAYOUT_KEY := "game/capitans_walk_touch_layout"

const Q := &"capitans_walk_q"
const W := &"capitans_walk_w"
const O := &"capitans_walk_o"
const P := &"capitans_walk_p"
const WHISTLE := &"capitans_walk_whistle"
const RESTART := &"capitans_walk_restart"
const PHOTO := &"capitans_walk_photo"
const EASY_LEFT := &"capitans_walk_easy_left"
const EASY_RIGHT := &"capitans_walk_easy_right"
const LEG_ACTIONS: Array[StringName] = [Q, W, O, P]
const LEG_BINDINGS: Array[String] = [
	"controls/capitans_walk_q", "controls/capitans_walk_w",
	"controls/capitans_walk_o", "controls/capitans_walk_p",
]
const RESTART_BINDING := "controls/capitans_walk_restart"
const WHISTLE_BINDING := "controls/capitans_walk_whistle"
const EASY_BINDINGS: Array[String] = [
	"controls/capitans_walk_easy_left", "controls/capitans_walk_easy_right",
]

const TUNABLES: Array[Dictionary] = [
	{
		"key": EASY_LEGS_KEY, "type": GameManifest.OPTION_TOGGLE, "default": false,
		"title": "Easy legs", "heading": "Walking assists - live",
		"description": "Two keys play one motor stride per leg choice. Release to stop.",
	},
	{
		"key": STEADY_KEY, "default": 0.0, "min": 0.0, "max": 1.0,
		"step": 0.05, "format": GameManifest.FORMAT_PERCENT,
		"title": "Steady", "heading": "Walking assists - live",
		"description": "Adds an upright torso spring. Does not automate your steps.",
	},
	{
		"key": WALK_SPEED_KEY, "type": GameManifest.OPTION_CHOICE,
		"default": 100, "title": "Walk speed", "heading": "Walking assists - live",
		"description": "Slows model time without changing the fixed-step physics.",
		"choices": [
			{"value": 100, "title": "100%"},
			{"value": 85, "title": "85%"},
			{"value": 70, "title": "70%"},
		],
	},
	{
		"key": LONG_WARNINGS_KEY, "type": GameManifest.OPTION_TOGGLE, "default": false,
		"title": "Long warnings", "heading": "Walking assists - live",
		"description": "Doubles every dog telegraph, including the remaining visible warning.",
	},
	{
		"key": TOUCH_LAYOUT_KEY, "type": GameManifest.OPTION_CHOICE, "default": 0,
		"title": "Touch layout", "heading": "Touch controls",
		"description": "Split the motor pads between thumbs, or group them under one hand.",
		"choices": [
			{"value": 0, "title": "Thumbs"},
			{"value": 1, "title": "Left-handed"},
			{"value": 2, "title": "Right-handed"},
		],
	},
]

const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": "controls/capitans_walk_q", "action": Q, "default": KEY_Q,
		"title": "Thighs A", "player": 0, "movement": true, "heading": "Leg motors",
		"description": "Left thigh forward, right thigh back. Opposing thighs cancel.",
	},
	{
		"key": "controls/capitans_walk_w", "action": W, "default": KEY_W,
		"title": "Thighs B", "player": 0, "movement": true, "heading": "Leg motors",
		"description": "Right thigh forward, left thigh back. Release to relax.",
	},
	{
		"key": "controls/capitans_walk_o", "action": O, "default": KEY_O,
		"title": "Calves A", "player": 0, "movement": true, "heading": "Leg motors",
		"description": "Bend the left knee and straighten the right knee.",
	},
	{
		"key": "controls/capitans_walk_p", "action": P, "default": KEY_P,
		"title": "Calves B", "player": 0, "movement": true, "heading": "Leg motors",
		"description": "Bend the right knee and straighten the left knee.",
	},
	{
		"key": WHISTLE_BINDING, "action": WHISTLE, "default": KEY_SPACE,
		"title": "Whistle", "player": 0, "heading": "The walk",
		"description": "Recall Capitan after 0.3 s. Six-second cooldown; release to call again.",
	},
	{
		"key": RESTART_BINDING, "action": RESTART, "default": KEY_R,
		"title": "Restart", "player": 0, "heading": "The walk",
		"description": "Reset the walker, Capitan and leash immediately, even after a fall.",
	},
	{
		"key": EASY_BINDINGS[0], "action": EASY_LEFT, "default": KEY_A,
		"title": "Easy left leg", "player": 0, "heading": "Easy legs",
		"description": "With Easy legs on, bend then plant the left leg. Both Easy keys cancel.",
	},
	{
		"key": EASY_BINDINGS[1], "action": EASY_RIGHT, "default": KEY_D,
		"title": "Easy right leg", "player": 0, "heading": "Easy legs",
		"description": "With Easy legs on, bend then plant the right leg. Release before repeating.",
	},
]

const ROUTES: Array[Dictionary] = []
const WALKERS: Array[Dictionary] = []
const STORE_CURRENCY := {}
const STORE_SLOTS: Array[Dictionary] = []
const STORE_ITEMS: Array[Dictionary] = []
const GALLERY_EXHIBITS: Array[Dictionary] = []
