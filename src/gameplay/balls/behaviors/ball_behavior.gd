class_name BallBehavior
extends RefCounted
## Strategy base for ball types (docs/02 §6.4). New ball = balls.json entry + a new
## behaviors/<behavior>_behavior.gd file; Ball code does not change.
## Hooks are no-ops by default.

var ball: RigidBody3D
var params: Dictionary = {}


func on_launch() -> void:
	pass


func on_impact(_body: Node, _impulse: float) -> void:
	pass


func on_physics(_delta: float) -> void:
	pass


func on_expire() -> void:
	pass
