module vector

import math

pub struct Vector2[T] {
pub mut:
	x T
	y T
}

// Property
pub fn (v &Vector2[T]) str() string {
	return 'Vector{x: ${v.x}: y:${v.y}}'
}

// Factory
pub fn new_vec_rad[T](rad T, length T) Vector2[T] {
	return Vector2[T]{math.cos(rad) * length, math.sin(rad) * length}
}

// Methods
pub fn (mut v Vector2[T]) set(x T, y T) {
	v.x, v.y = x, y
}

pub fn (mut v Vector2[T]) set_radian(rad T, length T) {
	v.x = math.cos(rad) * length
	v.y = math.sin(rad) * length
}

// Factory??
pub fn (v Vector2[T]) add(v1 Vector2[T]) Vector2[T] {
	return Vector2[T]{v.x + v1.x, v.y + v1.y}
}

pub fn (v Vector2[T]) add_normal(x T, y T) Vector2[T] {
	return Vector2[T]{v.x + x, v.y + y}
}

pub fn (v Vector2[T]) sub(v1 Vector2[T]) Vector2[T] {
	return Vector2[T]{v.x - v1.x, v.y - v1.y}
}

pub fn (v Vector2[T]) multiply(v1 Vector2[T]) Vector2[T] {
	return Vector2[T]{v.x * v1.x, v.y * v1.y}
}

pub fn (v Vector2[T]) middle(v1 Vector2[T]) Vector2[T] {
	return Vector2[T]{(v.x + v1.x) / 2, (v.y + v1.y) / 2}
}

pub fn (v Vector2[T]) dot(v1 Vector2[T]) T {
	return v.x * v1.x + v.y * v1.y
}

pub fn (v Vector2[T]) distance(v1 Vector2[T]) T {
	return math.sqrt(math.pow(v1.x - v.x, 2) + math.pow(v1.y - v.y, 2))
}

pub fn (v Vector2[T]) distance_squared(v1 Vector2[T]) T {
	return math.pow(v1.x - v.x, 2) + math.pow(v1.y - v.y, 2)
}

pub fn (v Vector2[T]) angle_r() T {
	return math.atan2(v.y, v.x)
}

pub fn (v Vector2[T]) angle() T {
	return v.angle_r() * 180 / math.pi
}

pub fn (v Vector2[T]) length() T {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

pub fn (v Vector2[T]) length_squared() T {
	return v.x * v.x + v.y * v.y
}

pub fn (v Vector2[T]) nor() Vector2[T] {
	len := v.length()
	return Vector2[T]{v.x / len, v.y / len}
}

pub fn (v Vector2[T]) angle_rv(v1 Vector2[T]) T {
	return math.atan2(v.y - v1.y, v.x - v1.x)
}

pub fn (v Vector2[T]) rotate(rad T) Vector2[T] {
	cos := math.cos(rad)
	sin := math.sin(rad)
	return Vector2[T]{v.x * cos - v.y * sin, v.x * sin + v.y * cos}
}

pub fn (v Vector2[T]) scale(by T) Vector2[T] {
	return Vector2[T]{v.x * by, v.y * by}
}

pub fn (v Vector2[T]) scale_normal(x T, y T) Vector2[T] {
	return Vector2[T]{v.x * x, v.y * y}
}

pub fn (v Vector2[T]) clone() Vector2[T] {
	return Vector2[T]{v.x, v.y}
}

pub fn (v Vector2[T]) equal(t Vector2[T]) bool {
	return v.x == t.x && v.y == t.y
}

// Origin math
pub fn (v Vector2[T]) apply_origin(t Origin, s Vector2[T]) Vector2[T] {
	return v.sub(t.Vector2.multiply(s))
}

pub fn is_straight_line[T](a Vector2[T], b Vector2[T], c Vector2[T]) bool {
	return math.abs((b.y - a.y) * (c.x - a.x) - (b.x - a.x) * (c.y - a.y)) < 0.001
}
