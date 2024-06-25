module sprite

import gg
import gx
import math
import framework.math.time
import framework.math.transform
import framework.math.vector
import framework.graphic.context

pub struct Sprite {
pub mut:
	id             int
	time           time.Time
	transforms     []transform.Transform
	textures       []gg.Image
	texture_i      int
	texture_fps    int
	texture_last_t f64
	texture_delta  f64
	// Attrs
	additive       bool
	always_visible bool
	origin         vector.Origin = vector.centre
	position       vector.Vector2[f64]
	z              f32
	size           vector.Vector2[f64]
	raw_size       vector.Vector2[f64]
	color          gx.Color = gx.white
	angle          f64

	flip_x bool
	flip_y bool
}

@[unsafe]
pub fn (mut sprite Sprite) free() {
	unsafe {
		free(sprite.time)

		for mut transform in sprite.transforms {
			transform.free()
		}

		free(sprite.position)
		free(sprite.size)
		free(sprite.raw_size)
	}
}

// Transform FNs
pub fn (mut sprite Sprite) apply_event(t transform.Transform, current_time f64) {
	match t.typ {
		.move {
			pos := t.as_vector(current_time)
			sprite.position.x = pos.x
			sprite.position.y = pos.y
		}
		.move_x {
			sprite.position.x = t.as_one(current_time)
		}
		.move_y {
			sprite.position.y = t.as_one(current_time)
		}
		.angle {
			sprite.angle = (t.as_one(current_time) * 180 / math.pi) * -1.0
		}
		.color {
			pos := t.as_three(current_time)
			sprite.color.r = u8(pos[0])
			sprite.color.g = u8(pos[1])
			sprite.color.b = u8(pos[2])
		}
		.fade {
			sprite.color.a = u8(t.as_one(current_time))
		}
		.scale {
			v := t.as_vector(current_time)
			sprite.size.x = sprite.raw_size.x * v.x
			sprite.size.y = sprite.raw_size.y * v.y
		}
		.scale_factor {
			factor := t.as_one(current_time)
			sprite.size.x = sprite.raw_size.x * factor
			sprite.size.y = sprite.raw_size.y * factor
		}
		// Special
		.additive {
			sprite.additive = true
		}
		.flip_vertically {
			sprite.flip_x = true
		}
		.flip_horizontally {
			sprite.flip_y = true
		}
		else {}
	}
}

pub fn (mut sprite Sprite) remove_transform_by_type(t transform.TransformType) {
	for mut transform in sprite.transforms {
		if transform.typ == t {
			index := sprite.transforms.index(transform)

			if index != -1 {
				sprite.transforms.delete(index)
			}
		}
	}
}

pub fn (mut sprite Sprite) reset_transform() {
	sprite.transforms = []transform.Transform{}
}

pub fn (mut sprite Sprite) add_transform(_t transform.Transform) {
	mut t := _t
	t.ensure_both_slots_is_filled_in()
	sprite.transforms << t
}

pub fn (mut sprite Sprite) reset_size_based_on_texture(arg CommonSpriteSizeResetArgument) {
	if (arg.size.x != 0 || arg.size.y != 0) && !arg.fit_size {
		sprite.raw_size = arg.size
		sprite.size = arg.size
	} else if (arg.source.x != 0 || arg.source.y != 0) && arg.fit_size {
		// Fit image within a given size and keep ratio.
		mut size := vector.Vector2[f64]{}

		// Use arg size if given
		if arg.size.x != 0 || arg.size.y != 0 {
			size.x = arg.size.x
			size.y = arg.size.y
		} else {
			texture := sprite.get_texture()
			size.x = f64(texture.width)
			size.y = f64(texture.height)
		}

		// Ratio
		mut ratio := (arg.source.x / size.x)

		sprite.raw_size = size.scale(ratio)
		sprite.size = size.scale(ratio)
	} else {
		mut texture := sprite.get_texture()

		// Get last texture if this is animation
		if sprite.texture_fps != 0 {
			texture = &sprite.textures[sprite.textures.len - 1]
		}

		sprite.raw_size.x = texture.width * arg.factor
		sprite.raw_size.y = texture.height * arg.factor

		sprite.size.x = texture.width * arg.factor
		sprite.size.y = texture.height * arg.factor
	}
}

pub fn (mut sprite Sprite) reset_attributes_based_on_transforms() {
	mut applied := []transform.TransformType{}

	// Might as well sort the transforms while we're at it
	sprite.transforms.sort(a.time.start < b.time.start)

	for i, t in sprite.transforms {
		if t.typ !in applied {
			applied << t.typ
			sprite.apply_event(t, t.time.start)
		}

		// Time
		if i == 0 {
			sprite.time.start = t.time.start
		}

		sprite.time.start = math.min(sprite.time.start, t.time.start)
		sprite.time.end = math.max(sprite.time.end, t.time.end)
	}
}

pub fn (mut sprite Sprite) reset_time_based_on_transforms() {
	for t in sprite.transforms {
		sprite.time.start = math.min(sprite.time.start, t.time.start)
		sprite.time.end = math.max(sprite.time.end, t.time.end)
	}
}

//
pub fn (mut sprite Sprite) is_drawable_at(update_time f64) bool {
	return update_time >= sprite.time.start && update_time <= sprite.time.end
}

// Texture
pub fn (mut sprite Sprite) get_texture() &gg.Image {
	if sprite.textures.len == 0 {
		return &gg.Image{}
	}

	return &sprite.textures[sprite.texture_i]
}

// Draw/Update FNs
const time_to_catch_up = f64(100.0)

pub fn (mut sprite Sprite) update(update_time f64) {
	// TODO: make better updater
	for t in sprite.transforms {
		// vfmt off
		if update_time >= t.time.start && update_time <= t.time.end + time_to_catch_up {
			// vfmt on
			sprite.apply_event(t, math.min(update_time, t.time.end)) // HACKHACHKHACK: extra 100ms to make sure the transform catch up
		}
	}

	sprite.update_sprite(update_time)
}

pub fn (mut sprite Sprite) update_sprite(update_time f64) {
	// TODO: Put this somewhere else
	if sprite.textures.len > 1 && sprite.texture_fps > 0 && sprite.texture_i < sprite.textures.len {
		if sprite.texture_last_t == 0.0 {
			sprite.texture_last_t = update_time
		}

		texture_frametime := 1000.0 / f64(sprite.texture_fps)

		delta := update_time - sprite.texture_last_t
		sprite.texture_delta += delta
		sprite.texture_last_t = update_time

		if sprite.texture_delta >= texture_frametime {
			sprite.texture_i++
			sprite.texture_delta -= texture_frametime

			sprite.texture_i = sprite.texture_i
		}
	}

	if sprite.texture_fps > 0 && sprite.texture_i >= sprite.textures.len {
		sprite.texture_i = sprite.textures.len - 1
	}
}

pub fn (mut sprite Sprite) update_peppy(update_time f64) {
	// osu!-esque update style from certain 2016 code
	// Note: This doesn't work
	mut has_future := false
	mut has_past := false
	mut should_draw := true

	// Check for active transform
	for t in sprite.transforms {
		if t.time.start >= update_time || t.time.end > update_time {
			has_future = true

			if t.time.start > update_time {
				continue
			}
		}

		if t.time.end <= update_time {
			has_past = true

			if t.time.end < update_time {
				continue
			}
		}

		should_draw = true
		sprite.apply_event(t, math.min(update_time, t.time.end))
	}

	// Past
	if !has_future && !should_draw {
		return
	}

	// Not current
	if !(has_future && has_past) && !should_draw {
		return
	}

	// Apply past transforms
	for i := sprite.transforms.len - 1; i >= 0; i-- {
		if sprite.transforms[i].time.end >= update_time {
			continue
		}
		sprite.apply_event(sprite.transforms[i], sprite.transforms[i].time.end)
	}

	// Apply future transforms
	if has_future {
		for i := 0; i < sprite.transforms.len; i++ {
			if sprite.transforms[i].time.start < update_time {
				continue
			}
			sprite.apply_event(sprite.transforms[i], sprite.transforms[i].time.start)
		}
	}
}

pub fn (mut sprite Sprite) draw(arg CommonSpriteArgument) {
	if sprite.is_drawable_at(arg.time) || sprite.always_visible {
		size := sprite.size
			.scale(arg.camera.scale * arg.scale)

		pos := sprite.position
			.scale(arg.camera.scale)
			.apply_origin(sprite.origin, size)
			.add(arg.camera.offset)

		if arg.batch {
			arg.ctx.draw_image_with_config(context.DrawImageConfig{
				img: sprite.get_texture()
				img_id: sprite.get_texture().id
				img_rect: gg.Rect{
					x: f32(pos.x)
					y: f32(pos.y)
					width: f32(size.x)
					height: f32(size.y)
				}
				rotate: f32(sprite.angle)
				color: sprite.color
				effect: [.alpha, .add][int(sprite.additive)]
				origin: sprite.origin
				flip_x: sprite.flip_x
				flip_y: sprite.flip_x
				z: sprite.z
			})
		} else {
			arg.ctx.draw_image_with_config(context.DrawImageConfig{
				img: sprite.get_texture()
				img_id: sprite.get_texture().id
				img_rect: gg.Rect{
					x: f32(pos.x)
					y: f32(pos.y)
					width: f32(size.x)
					height: f32(size.y)
				}
				rotate: f32(sprite.angle)
				color: sprite.color
				effect: [.alpha, .add][int(sprite.additive)]
				origin: sprite.origin
				flip_x: sprite.flip_x
				flip_y: sprite.flip_x
				z: sprite.z
			})
		}
	}
}
