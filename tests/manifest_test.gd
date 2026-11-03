extends SceneTree

## The game's first registration must work through the host's ordinary catalog path.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var definition := load("res://games/capitans_walk/game.gd") as Script
	if definition == null:
		printerr("Capitan's Walk manifest script did not load.")
		quit(1)
		return
	var manifest: GameManifest = definition.call("manifest")
	if manifest == null or not manifest.is_valid() \
		or GameCatalog.get_manifest(Options.GAME_ID) == null:
		printerr("The host must discover a valid Capitan's Walk manifest.")
		quit(1)
		return
	if manifest.uses_shell_round_rules or manifest.supports_multiplayer \
		or manifest.supports_cpu_opponent:
		printerr("The physics spike must use solo, game-owned ending rules.")
		quit(1)
		return
	var scene := load(manifest.gameplay_scene_path) as PackedScene
	if scene == null:
		printerr("The manifest must point to a loadable gameplay scene.")
		quit(1)
		return
	print("Capitan's Walk manifest tests passed.")
	quit(0)
