extends RefCounted
## Перевод безопасной области физического экрана в координаты viewport.


## Vector4: left, top, right, bottom.
static func insets(viewport_size: Vector2) -> Vector4:
	var safe := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var sx := viewport_size.x / float(window_size.x)
	var sy := viewport_size.y / float(window_size.y)
	var left := maxf(0.0, float(safe.position.x) * sx)
	var top := maxf(0.0, float(safe.position.y) * sy)
	var right := maxf(0.0, float(window_size.x - safe.end.x) * sx)
	var bottom := maxf(0.0, float(window_size.y - safe.end.y) * sy)
	# Защита от некорректных данных отдельных Android-оболочек.
	return Vector4(
		minf(left, viewport_size.x * 0.12),
		minf(top, viewport_size.y * 0.12),
		minf(right, viewport_size.x * 0.12),
		minf(bottom, viewport_size.y * 0.12)
	)
