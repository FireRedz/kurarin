module graphics

import gx
import core.osu.x
import core.osu.system.skin
import core.common.settings
import framework.math.time as time2
import framework.math.vector
import framework.graphic.sprite

const debug_length = 16

// debug cursor
pub struct DebugCursor {
	sprite.Sprite
mut:
	deltas   [debug_length]vector.Vector2[f64]
	deltas_i int

	last_updated_time    f64
	catch_up_sixty_delta f64
}

pub fn (mut debug_cursor DebugCursor) draw(arg sprite.CommonSpriteArgument) {
	for i := 0; i < debug_cursor.deltas.len; i++ {
		// Color based off of the index
		r := u8(255 * (f64(i) / f64(debug_cursor.deltas.len)))
		g := u8(25 * (f64(i) / f64(debug_cursor.deltas.len)))
		b := u8(25 * (f64(i) / f64(debug_cursor.deltas.len)))

		arg.ctx.draw_rect_filled(f32(
			(debug_cursor.deltas[i].x - 8) * x.resolution.playfield_scale + x.resolution.offset.x),
			f32((debug_cursor.deltas[i].y - 8) * x.resolution.playfield_scale +
			x.resolution.offset.y), 16, 16, gx.Color{r, g, b, 255})
	}

	arg.ctx.draw_rect_filled(f32((debug_cursor.position.x - 16) * x.resolution.playfield_scale +
		x.resolution.offset.x), f32((debug_cursor.position.y - 16) * x.resolution.playfield_scale +
		x.resolution.offset.y), 32, 32, gx.red)
}

pub fn (mut debug_cursor DebugCursor) update(update_time f64) {
	debug_cursor.Sprite.update(update_time)

	delta := update_time - debug_cursor.last_updated_time
	debug_cursor.catch_up_sixty_delta += delta

	if debug_cursor.catch_up_sixty_delta >= osu_cursor_trail_delta {
		debug_cursor.catch_up_sixty_delta -= osu_cursor_trail_delta

		debug_cursor.deltas_i++
		debug_cursor.deltas[debug_cursor.deltas_i % graphics.debug_length].x = debug_cursor.position.x
		debug_cursor.deltas[debug_cursor.deltas_i % graphics.debug_length].y = debug_cursor.position.y

		debug_cursor.catch_up_sixty_delta -= osu_cursor_trail_delta
	}

	debug_cursor.last_updated_time = update_time
}

// Factory
pub fn DebugCursor.create() &DebugCursor {
	mut cursor := &DebugCursor{
		always_visible: true
		textures: [
			skin.get_texture('cursor'),
		]
	}

	cursor.add_transform(
		typ: .scale_factor
		time: time2.Time{0, 0}
		before: [settings.global.gameplay.skin.cursor.size]
	)

	cursor.reset_size_based_on_texture()
	cursor.reset_attributes_based_on_transforms()

	return cursor
}
