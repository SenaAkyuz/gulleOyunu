class_name LevelCamera
extends Camera3D
## Fixed perspective camera (S-007). All values come from rules.camera, optionally merged with
## the level's camera_override. Orbits the look-at point (0, look_at_height, 0) by yaw/pitch.


func configure(cfg: Dictionary) -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = float(cfg["fov_deg"])
	keep_aspect = KEEP_WIDTH if str(cfg["keep_aspect"]) == "width" else KEEP_HEIGHT
	var target := Vector3(0.0, float(cfg["look_at_height"]), 0.0)
	var pitch := deg_to_rad(float(cfg["pitch_deg"]))
	var yaw := deg_to_rad(float(cfg["yaw_deg"]))
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * float(cfg["distance"])
	global_position = target + offset.rotated(Vector3.UP, yaw)
	look_at(target, Vector3.UP)
