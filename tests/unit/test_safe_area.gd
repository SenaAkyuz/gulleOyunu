extends GutTest
## SafeArea.to_viewport_margins: window-pixel safe rect -> viewport-pixel HUD margins (K-035).


func test_full_screen_safe_area_gives_zero() -> void:
	var m := SafeArea.to_viewport_margins(Rect2(0, 0, 1080, 1920), Vector2(1080, 1920), Vector2(1080, 1920))
	assert_eq(m, Vector4.ZERO)


func test_iphone_notch_scaled_to_viewport() -> void:
	# iPhone 15 Pro: 1179 x 2556 px, safe top 177 px (59 pt), bottom 102 px (34 pt).
	var window := Vector2(1179, 2556)
	var viewport := Vector2(1080, 2556.0 * 1080.0 / 1179.0)
	var m := SafeArea.to_viewport_margins(Rect2(0, 177, 1179, 2556 - 177 - 102), window, viewport)
	assert_almost_eq(m.y, 162.1, 0.2)
	assert_almost_eq(m.w, 93.4, 0.2)
	assert_almost_eq(m.x, 0.0, 0.001)
	assert_almost_eq(m.z, 0.0, 0.001)


func test_landscape_style_side_insets() -> void:
	var m := SafeArea.to_viewport_margins(Rect2(50, 0, 980, 1920), Vector2(1080, 1920), Vector2(1080, 1920))
	assert_almost_eq(m.x, 50.0, 0.001)
	assert_almost_eq(m.z, 50.0, 0.001)


func test_invalid_input_gives_zero() -> void:
	assert_eq(SafeArea.to_viewport_margins(Rect2(), Vector2(1080, 1920), Vector2(1080, 1920)), Vector4.ZERO)
	assert_eq(SafeArea.to_viewport_margins(Rect2(0, 0, 10, 10), Vector2.ZERO, Vector2(1080, 1920)), Vector4.ZERO)


func test_fake_margins_come_from_rules() -> void:
	SafeArea.fake_enabled = true
	var m := SafeArea.margins(get_tree().root)
	SafeArea.fake_enabled = false
	var f: Dictionary = GameConfig.rule("dev.fake_safe_area_px")
	assert_eq(m, Vector4(f.left, f.top, f.right, f.bottom))
