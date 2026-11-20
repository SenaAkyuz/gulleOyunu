class_name SafeArea
extends RefCounted
## Phone notch / home-indicator safe area for the HUD (K-035, docs/04 §3.0).
## On mobile: DisplayServer safe area (window pixels) converted to viewport pixels
## (stretch canvas_items + expand: 1080 wide, height grows on tall phones).
## On desktop: zero, or rules.dev.fake_safe_area_px while the dev toggle (S key) is on.

## Dev toggle (survives level reloads, like LevelLoader.stress_mode).
static var fake_enabled: bool = false


## Margins as Vector4(left, top, right, bottom) in viewport pixels.
static func margins(viewport: Viewport) -> Vector4:
	if fake_enabled:
		var f: Dictionary = GameConfig.rule("dev.fake_safe_area_px")
		return Vector4(float(f.left), float(f.top), float(f.right), float(f.bottom))
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var window := Vector2(DisplayServer.window_get_size())
	return to_viewport_margins(Rect2(DisplayServer.get_display_safe_area()), window,
			viewport.get_visible_rect().size)


## Pure conversion (unit tested): safe rect and window size in window pixels -> viewport margins.
static func to_viewport_margins(safe: Rect2, window_size: Vector2, viewport_size: Vector2) -> Vector4:
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	var k := viewport_size / window_size
	var left := maxf(safe.position.x, 0.0) * k.x
	var top := maxf(safe.position.y, 0.0) * k.y
	var right := maxf(window_size.x - safe.end.x, 0.0) * k.x
	var bottom := maxf(window_size.y - safe.end.y, 0.0) * k.y
	return Vector4(left, top, right, bottom)
