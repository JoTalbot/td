extends RefCounted
## Награда за связную сеть контролируемых дорог.
## Бонус небольшой и ограничен сверху, чтобы война не превращалась в гринд.

const PER_EXTRA_ROUTE := 0.02
const MAX_BONUS := 0.10

static func multiplier(route_control: Dictionary, routes: Array, a: String, b: String) -> float:
	var key := _route_key(a, b)
	var owner := String(route_control.get(key, ""))
	if owner == "":
		return 1.0
	var route_count := _component_route_count(route_control, routes, owner, a, b)
	return 1.0 + minf(maxi(route_count - 1, 0) * PER_EXTRA_ROUTE, MAX_BONUS)

static func component_route_count(route_control: Dictionary, routes: Array, owner: String, a: String, b: String) -> int:
	return _component_route_count(route_control, routes, owner, a, b)

static func _component_route_count(route_control: Dictionary, routes: Array, owner: String, a: String, b: String) -> int:
	var queue: Array[String] = [a, b]
	var seen: Dictionary = {}
	var edges: Dictionary = {}
	while not queue.is_empty():
		var city := queue.pop_front()
		if seen.has(city):
			continue
		seen[city] = true
		for route in routes:
			if route.size() < 2:
				continue
			var left := String(route[0])
			var right := String(route[1])
			if left != city and right != city:
				continue
			var edge_key := _route_key(left, right)
			if String(route_control.get(edge_key, "")) != owner:
				continue
			edges[edge_key] = true
			var next_city := right if left == city else left
			if not seen.has(next_city):
				queue.append(next_city)
	return edges.size()

static func _route_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
