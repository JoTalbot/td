extends RefCounted
## Награда за связную сеть контролируемых дорог.
## Бонус небольшой и ограничен сверху, чтобы война не превращалась в гринд.

const PER_EXTRA_ROUTE: float = 0.02
const MAX_BONUS: float = 0.10

static func multiplier(route_control: Dictionary, routes: Array, a: String, b: String) -> float:
	var key: String = route_key(a, b)
	var owner: String = String(route_control.get(key, ""))
	if owner == "":
		return 1.0
	var component: int = _component_size(route_control, routes, owner, a, b)
	# Одна контролируемая дорога = базовая награда. Бонус начинается
	# только со второй дороги той же связной сети.
	var extra_routes: int = maxi(component - 2, 0)
	return 1.0 + minf(float(extra_routes) * PER_EXTRA_ROUTE, MAX_BONUS)

static func component_size(route_control: Dictionary, routes: Array, owner: String, a: String, b: String) -> int:
	return _component_size(route_control, routes, owner, a, b)

static func _component_size(route_control: Dictionary, routes: Array, owner: String, a: String, b: String) -> int:
	var nodes: Dictionary = {}
	var queue: Array[String] = [a, b]
	var seen: Dictionary = {}
	while not queue.is_empty():
		var city: String = queue.pop_front()
		if seen.has(city):
			continue
		seen[city] = true
		for route in routes:
			if route.size() < 2:
				continue
			var left: String = String(route[0])
			var right: String = String(route[1])
			if left != city and right != city:
				continue
			var edge_key: String = route_key(left, right)
			if String(route_control.get(edge_key, "")) != owner:
				continue
			nodes[left] = true
			nodes[right] = true
			var next_city: String = right if left == city else left
			if not seen.has(next_city):
				queue.append(next_city)
	return nodes.size()

## Canonical route key shared by gameplay and deterministic regression tests.
static func route_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
