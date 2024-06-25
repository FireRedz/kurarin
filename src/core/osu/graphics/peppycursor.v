module graphics

import gg
import core.osu.x
import core.osu.system.skin
import core.common.settings
import framework.math.time as time2
import framework.math.easing
import framework.graphic.sprite
import framework.graphic.context

const osu_cursor_trail_delta = f64(1000.0 / 120.0) // 120FPS

// short-length trail, 120fps frame delay
pub struct PeppyCursor {
	sprite.Sprite
mut:
	trails []&sprite.Sprite

	last_updated_time    f64
	catch_up_sixty_delta f64
}

pub fn (mut peppy_cursor PeppyCursor) draw(arg sprite.CommonSpriteArgument) {
	// The trail
	for i := 0; i < peppy_cursor.trails.len; i++ {
		if !peppy_cursor.trails[i].is_drawable_at(peppy_cursor.last_updated_time) {
			continue // Preferably, I want to remove this trail from the list, but it's better to leave the draw function to just do the drawing.
		}

		pos := peppy_cursor.trails[i].position.apply_origin(peppy_cursor.origin, peppy_cursor.trails[i].size)

		arg.ctx.draw_image_with_config(context.DrawImageConfig{
			img: &peppy_cursor.textures[1]
			img_id: peppy_cursor.textures[1].id
			img_rect: gg.Rect{
				x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x)
				y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y)
				width: f32(peppy_cursor.trails[i].size.x * x.resolution.playfield_scale)
				height: f32(peppy_cursor.trails[i].size.y * x.resolution.playfield_scale)
			}
			color: peppy_cursor.trails[i].color
			effect: .alpha
		})
	}

	// Cursor
	pos := peppy_cursor.position.apply_origin(peppy_cursor.origin, peppy_cursor.size)

	arg.ctx.draw_image_with_config(context.DrawImageConfig{
		img: &peppy_cursor.textures[0]
		img_id: peppy_cursor.textures[0].id
		img_rect: gg.Rect{
			x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x)
			y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y)
			width: f32(peppy_cursor.size.x * x.resolution.playfield_scale)
			height: f32(peppy_cursor.size.y * x.resolution.playfield_scale)
		}
		effect: .alpha
		color: peppy_cursor.color
	})
}

pub fn (mut peppy_cursor PeppyCursor) update(update_time f64) {
	peppy_cursor.Sprite.update(update_time)

	delta := update_time - peppy_cursor.last_updated_time
	peppy_cursor.catch_up_sixty_delta += delta

	if peppy_cursor.catch_up_sixty_delta >= graphics.osu_cursor_trail_delta {
		mut new_trail := &sprite.Sprite{
			textures: [peppy_cursor.textures[1]]
		}

		new_trail.add_transform(
			typ: .fade
			easing: easing.quad_out
			time: time2.Time{update_time, update_time + 150}
			before: [255.0]
			after: [0.0]
		)

		new_trail.add_transform(
			typ: .move
			easing: easing.quad_out
			time: time2.Time{update_time, update_time + 150}
			before: [peppy_cursor.position.x, peppy_cursor.position.y]
		)

		new_trail.add_transform(
			typ: .scale_factor
			time: time2.Time{update_time, update_time}
			before: [
				settings.global.gameplay.skin.cursor.size,
			]
		)

		new_trail.reset_size_based_on_texture()
		new_trail.reset_attributes_based_on_transforms()

		peppy_cursor.trails << new_trail

		peppy_cursor.catch_up_sixty_delta -= graphics.osu_cursor_trail_delta
	}

	// Update + Delete unusued trail
	for i := 0; i < peppy_cursor.trails.len; i++ {
		if update_time > peppy_cursor.trails[i].time.end {
			peppy_cursor.trails = peppy_cursor.trails[1..]
			i--
			continue
		}

		peppy_cursor.trails[i].update(update_time)
	}

	peppy_cursor.last_updated_time = update_time
}

// Factory
pub fn PeppyCursor.create() &PeppyCursor {
	mut cursor := &PeppyCursor{
		always_visible: true
		textures: [
			skin.get_texture('cursor'),
			skin.get_texture('cursortrail'),
			skin.get_texture('cursor-top'),
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
