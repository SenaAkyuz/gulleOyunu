class_name SurfaceTexture
extends RefCounted
## Puts an albedo texture on a StandardMaterial3D with object-space triplanar mapping (Faz 7):
## no UVs needed, every box size tiles the same (rules.visuals.texture_world_scale), and the
## texture moves with the block. Textures are loaded once and shared.

static var _cache: Dictionary = {}


## True when the texture exists and was applied.
static func apply(mat: StandardMaterial3D, path: String) -> bool:
	if path.is_empty() or path.ends_with("/.png") or not ResourceLoader.exists(path):
		return false
	if not _cache.has(path):
		_cache[path] = load(path)
	mat.albedo_texture = _cache[path]
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * float(GameConfig.rule("visuals.texture_world_scale"))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return true
