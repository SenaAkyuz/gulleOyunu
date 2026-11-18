class_name TrajectoryPreview
extends MultiMeshInstance3D
## Dotted trajectory preview (docs/01 §3.2). Dots sit on the exact path the ball will fly
## (Ballistics.point_at), one every rules.aim.preview_dot_interval_sec, at most `max_dots`
## (level aim_preview_dots, else rules.aim.default_preview_dots), and stop at the target so
## they never run through the tower. Fewer dots = shorter preview = harder level (docs/03 §6.1).

## Grey-box dot look (Faz 8 adds the pulse).
const DOT_RADIUS := 0.07
const DOT_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var max_dots: int = 0
var interval: float = 0.0


func setup(dot_count: int, dot_interval: float) -> void:
	max_dots = dot_count
	interval = dot_interval
	top_level = true
	global_transform = Transform3D.IDENTITY
	var dot := SphereMesh.new()
	dot.radius = DOT_RADIUS
	dot.height = DOT_RADIUS * 2.0
	dot.radial_segments = 8
	dot.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = DOT_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = max_dots
	mm.visible_instance_count = 0
	multimesh = mm
	visible = false


## Shows the dots for a ball leaving `from` with `velocity`, ending at time `t_end` (target reached).
func show_path(from: Vector3, velocity: Vector3, gravity: float, t_end: float) -> void:
	var count := 0
	for i in range(1, max_dots + 1):
		var t := interval * i
		if t > t_end:
			break
		multimesh.set_instance_transform(count, Transform3D(Basis.IDENTITY,
				Ballistics.point_at(from, velocity, gravity, t)))
		count += 1
	multimesh.visible_instance_count = count
	visible = count > 0


func hide_path() -> void:
	visible = false
	if multimesh:
		multimesh.visible_instance_count = 0
