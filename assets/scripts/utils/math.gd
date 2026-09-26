extends Node

class_name Math



static func fraction(x: float) -> float:
	return x - floorf(x)

static func smooth_step(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

static func pseudo_random(x: float, h1: float = 12.9989, h2: float = 43758.54) -> float:
	return fraction(sin(x*h1)*h2)

static func pseudo_random_2d(x: float, y: float, h1x: float = 12.9989, h1y: float = 31.6382, h2: float = 43758.54) -> float:
	return fraction(sin(x * h1x + y * h1y) * h2)

static func value_noise(x: float, h1: float = 12.9989, h2: float = 43758.54) -> float:
	return _smooth_fraction(x) * _cell_hash(x + 1.0, h1, h2) + (1.0 - _smooth_fraction(x)) * _cell_hash(x, h1, h2)

static func value_noise_2d(x: float, y: float, h1x: float = 12.9989, h1y: float = 31.6382, h2: float = 43758.54) -> float:
	var x0 := floorf(x)
	var y0 := floorf(y)
	var tx := smooth_step(fraction(x))
	var ty := smooth_step(fraction(y))
	var a := _cell_hash_2d(x0,     y0,     h1x, h1y, h2)
	var b := _cell_hash_2d(x0 + 1, y0,     h1x, h1y, h2)
	var c := _cell_hash_2d(x0,     y0 + 1, h1x, h1y, h2)
	var d := _cell_hash_2d(x0 + 1, y0 + 1, h1x, h1y, h2)
	var ab := lerpf(a, b, tx)
	var cd := lerpf(c, d, tx)
	return lerpf(ab, cd, ty)

static func fractal_noise(x: float, h1: float = 12.9989, h2: float = 43758.54, iterations: int = 8) -> float:
	# https://www.desmos.com/calculator/i5x9mkslt3
	var retval: float = 0.0
	for j in range(iterations):
		retval = retval + value_noise(x * pow(2.0, float(j)), h1, h2) / pow(2.0, float(j))	
	return retval * 0.5

static func fractal_noise_2d(x: float, y: float, h1x: float = 12.9989, h1y: float = 31.6382, h2: float = 43758.54, iterations: int = 8) -> float:
	var value := 0.0
	var amplitude := 1.0
	var frequency := 1.0
	var amplitude_sum := 0.0
	for j in range(iterations):
		value += value_noise_2d(x * frequency, y * frequency, h1x, h1y, h2) * amplitude
		amplitude_sum += amplitude
		frequency *= 2.0
		amplitude *= 0.5
	return value / amplitude_sum

static func _smooth_fraction(x: float) -> float:
	return smooth_step(fraction(x))

static func _cell_hash(x: float, h1: float = 12.9989, h2: float = 43758.54) -> float:
	return pseudo_random(floorf(x), h1, h2)


static func _cell_hash_2d(x: float, y: float, h1x: float = 12.9989, h1y: float = 31.6382, h2: float = 43758.54) -> float:
	return pseudo_random_2d(floorf(x), floorf(y), h1x, h1y, h2)



