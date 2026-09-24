extends RefCounted
## Pure spatial queries shared by vision, decoys, cover, navigation, and tests.
static func segment_fraction(a: Vector2, b: Vector2, rect: Rect2) -> float:
	var delta: Vector2 = b - a
	var near_t: float = 0.0
	var far_t: float = 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.00001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]:
				return 1.0
		else:
			var t1: float = (rect.position[axis] - a[axis]) / delta[axis]
			var t2: float = (rect.end[axis] - a[axis]) / delta[axis]
			near_t = maxf(near_t, minf(t1, t2))
			far_t = minf(far_t, maxf(t1, t2))
			if near_t > far_t:
				return 1.0
	return clampf(near_t, 0.0, 1.0)

static func visible(a: Vector2, b: Vector2, walls: Array) -> bool:
	for wall: Rect2 in walls:
		if segment_fraction(a, b, wall) < 0.999:
			return false
	return true

static func clip_ray(a: Vector2, b: Vector2, walls: Array) -> Vector2:
	var fraction: float = 1.0
	for wall: Rect2 in walls:
		fraction = minf(fraction, segment_fraction(a, b, wall))
	return a.lerp(b, fraction)

static func in_cone(origin: Vector2, facing: Vector2, target: Vector2, radius: float, half_angle: float) -> bool:
	var delta: Vector2 = target - origin
	return delta.length() <= radius and (delta.length() < 0.01 or facing.dot(delta.normalized()) >= cos(half_angle))

static func cover_face(point: Vector2, walls: Array, distance_limit: float = 0.95) -> Dictionary:
	var result: Dictionary = {}
	var best: float = distance_limit
	for wall: Rect2 in walls:
		var faces: Array = [
			[Vector2(wall.position.x - 0.48, clampf(point.y, wall.position.y, wall.end.y)), Vector2.LEFT],
			[Vector2(wall.end.x + 0.48, clampf(point.y, wall.position.y, wall.end.y)), Vector2.RIGHT],
			[Vector2(clampf(point.x, wall.position.x, wall.end.x), wall.position.y - 0.48), Vector2.UP],
			[Vector2(clampf(point.x, wall.position.x, wall.end.x), wall.end.y + 0.48), Vector2.DOWN]
		]
		for face: Array in faces:
			var d: float = point.distance_to(face[0])
			if d < best and visible(point, face[0], walls):
				best = d
				result = {"point": face[0], "normal": face[1], "wall": wall}
	return result
