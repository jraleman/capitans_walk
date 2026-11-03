extends RefCounted

## A wrist-looped rope pulls both endpoints equally; it never pushes or disconnects.

const DEFAULT_LENGTH := 1.8
const START_SLACK := 0.3
const STIFFNESS := 360.0
const DAMPING := 24.0
const MAX_FORCE := 260.0
const EPSILON := 0.0000001

var length := DEFAULT_LENGTH
var separation := 0.0
var tension := 0.0
var force := Vector2.ZERO


## X is along the path and Vector2.y is lateral Z; vertical drop is visual only.
func update(
	hand: Vector2, collar: Vector2, hand_velocity: Vector2, collar_velocity: Vector2
) -> bool:
	if not hand.is_finite() or not collar.is_finite() \
		or not hand_velocity.is_finite() or not collar_velocity.is_finite() \
		or not is_finite(length) or length <= 0.0:
		push_error("Capitan's Walk leash requires finite endpoints and a positive length.")
		return false
	var offset := collar - hand
	separation = offset.length()
	tension = 0.0
	force = Vector2.ZERO
	if separation <= length or separation < EPSILON:
		return true
	var direction := offset / separation
	var extension_speed := (collar_velocity - hand_velocity).dot(direction)
	tension = clampf(STIFFNESS * (separation - length) + DAMPING * extension_speed,
		0.0, MAX_FORCE)
	force = direction * tension
	return true


## Reset clears the measured force without changing a breed's authored rope length.
func reset() -> void:
	separation = 0.0
	tension = 0.0
	force = Vector2.ZERO


## Hidden force history belongs in replay/determinism comparisons too.
func snapshot() -> Dictionary:
	return {"length": length, "separation": separation, "tension": tension, "force": force}
