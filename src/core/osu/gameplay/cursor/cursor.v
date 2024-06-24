// TODO: move this somewhere else

module cursor

import gg
import gx
import sync
import framework.graphic.sprite
import framework.graphic.context
import framework.math.easing
import framework.math.vector
import framework.math.time as time2
import core.common.settings
import core.osu.parsers.beatmap.object as gameobject
import core.osu.system.skin
import core.osu.x

const used_imports = gameobject.used_imports
const max_valid_style = 2

const osu_cursor_trail_delta = f64(1000.0 / 120.0) // 120FPS

pub struct Cursor {
	sprite.Sprite
pub mut:
	mutex       &sync.Mutex      = sync.new_mutex()
	ctx         &context.Context = unsafe { nil }
	trails      []&sprite.Sprite
	trail_color gx.Color = gx.Color{0, 25, 100, u8(255 * 0.5)}
	delta_pos   []vector.Vector2[f64]
	delta_pos_i int
	manual      bool // Manual means the user can overwrite this cursor position.
	// Game control
	left_button  bool
	right_button bool
	left_mouse   bool
	right_mouse  bool
mut:
	sixty_delta   f64
	last_time     f64
	last_position vector.Vector2[f64]
}

pub fn (mut cursor Cursor) draw(_ sprite.CommonSpriteArgument) {
	cursor.mutex.@lock()

	// TODO: This is fucked, fix this
	if settings.global.gameplay.skin.cursor.style == 2 {
		for i, trail in cursor.delta_pos {
			size := cursor.size.scale(0.9 * (0.1 + f64(i) / f64(cursor.delta_pos.len) * 0.9))

			pos := trail.sub(cursor.origin.Vector2.multiply(x: size.x, y: size.y))
			cursor.ctx.draw_image_with_config(context.DrawImageConfig{
				img: &cursor.textures[3]
				img_id: cursor.textures[3].id
				img_rect: gg.Rect{
					x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x)
					y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y)
					width: f32(size.x * x.resolution.playfield_scale)
					height: f32(size.y * x.resolution.playfield_scale)
				}
				color: cursor.trail_color
				effect: .add
			})
		}
	} else {
		// Normal trails
		for mut trail in cursor.trails {
			if !trail.is_drawable_at(cursor.last_time) {
				continue
			}

			pos := trail.position.sub(trail.origin.Vector2.multiply(x: trail.size.x, y: trail.size.y))

			cursor.ctx.draw_image_with_config(context.DrawImageConfig{
				img: trail.get_texture()
				img_id: trail.get_texture().id
				img_rect: gg.Rect{
					x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x)
					y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y)
					width: f32(trail.size.x * x.resolution.playfield_scale)
					height: f32(trail.size.y * x.resolution.playfield_scale)
				}
				color: trail.color
				effect: .alpha
			})
		}
	}

	// Cursor
	pos := cursor.position.sub(cursor.origin.Vector2.multiply(x: cursor.size.x, y: cursor.size.y))

	mut cursor_additive := false
	mut cursor_color := cursor.color
	mut cursor_img := &cursor.textures[0]

	// Additive Cursor
	if settings.global.gameplay.skin.cursor.style == 2 {
		cursor_additive = true
		cursor_color = gx.white
		cursor_img = &cursor.textures[2]
	}

	cursor.ctx.draw_image_with_config(context.DrawImageConfig{
		img: cursor_img
		img_id: cursor_img.id
		img_rect: gg.Rect{
			x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x)
			y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y)
			width: f32(cursor.size.x * x.resolution.playfield_scale)
			height: f32(cursor.size.y * x.resolution.playfield_scale)
		}
		effect: [.alpha, .add][int(cursor_additive)]
		color: cursor_color
	})

	cursor.mutex.unlock()
}

pub fn (mut cursor Cursor) update(update_time f64, _delta f64) {
	cursor.mutex.@lock()
	cursor.Sprite.update(update_time) // Update the main cursor itself

	// Delta
	delta := update_time - cursor.last_time

	// Time
	cursor.sixty_delta += delta

	// Normal trails
	// vfmt off
	if settings.global.gameplay.skin.cursor.style == 0
		&& cursor.sixty_delta >= osu_cursor_trail_delta {
		// vfmt on
		mut trail := &sprite.Sprite{
			textures: [cursor.textures[1]]
		}
		trail.add_transform(
			typ: .fade
			easing: easing.quad_out
			time: time2.Time{update_time, update_time + 150}
			before: [255.0]
			after: [0.0]
		)
		trail.add_transform(
			typ: .move
			easing: easing.quad_out
			time: time2.Time{update_time, update_time + 150}
			before: [cursor.position.x, cursor.position.y]
		)
		trail.add_transform(
			typ: .scale_factor
			time: time2.Time{update_time, update_time}
			before: [
				settings.global.gameplay.skin.cursor.size,
			]
		)
		trail.reset_size_based_on_texture()
		trail.reset_attributes_based_on_transforms()
		cursor.trails << trail

		// vfmt off
		cursor.sixty_delta -= osu_cursor_trail_delta
		// vfmt on
	}

	// Long cursor Trail
	if settings.global.gameplay.skin.cursor.style == 2 && delta > 0.0 {
		points := int(cursor.position.distance(cursor.last_position)) * 2
		cursor.delta_pos << cursor.last_position

		for i := 1; i <= points; i++ {
			cursor.delta_pos << cursor.position.sub(cursor.last_position).scale(f64(i) / f64(points)).add(cursor.last_position)
		}

		times := cursor.delta_pos.len / (6.0 * (60.0 / delta)) + 1

		if cursor.delta_pos.len > 0 {
			if int(times) < cursor.delta_pos.len {
				cursor.delta_pos = cursor.delta_pos[int(times)..]
			} else {
				cursor.delta_pos = cursor.delta_pos[cursor.delta_pos.len..]
			}
		}
	}

	// TODO: this is fucked
	for mut trail in cursor.trails {
		if update_time > trail.time.end {
			cursor.trails.delete(cursor.trails.index(trail))
			continue
		}

		trail.update(update_time)
	}

	// Done
	cursor.last_position.x = cursor.position.x
	cursor.last_position.y = cursor.position.y
	cursor.last_time = update_time

	cursor.mutex.unlock()
}

// Factory
pub fn make_cursor(mut ctx context.Context) &Cursor {
	mut cursor := &Cursor{
		ctx: ctx
		always_visible: true
	}
	cursor.textures << skin.get_texture('cursor')
	cursor.textures << skin.get_texture('cursortrail')
	cursor.textures << skin.get_texture('cursor-top')
	cursor.textures << skin.get_texture('cursortrailfx')
	cursor.add_transform(
		typ: .scale_factor
		time: time2.Time{0, 0}
		before: [settings.global.gameplay.skin.cursor.size]
	)

	//
	cursor.reset_size_based_on_texture()
	cursor.reset_attributes_based_on_transforms()

	return cursor
}
