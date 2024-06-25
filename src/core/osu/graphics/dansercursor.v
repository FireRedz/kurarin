module graphics

import gg
import gx
import core.osu.x
import core.osu.system.skin
import core.common.settings
import framework.math.time as time2
import framework.math.vector
import framework.graphic.sprite
import framework.graphic.context

// long-length trail, (old) danser style
pub struct DanserCursor {
	sprite.Sprite
mut:
	last_position     vector.Vector2[f64]
	last_positions    []vector.Vector2[f64]
	last_updated_time f64
}

pub fn (mut danser_cursor DanserCursor) draw(arg sprite.CommonSpriteArgument) {
	// Trail
	for i := 0; i < danser_cursor.last_positions.len; i++ {
		size := danser_cursor.size.scale(0.9 * (0.1 +
			f64(i) / f64(danser_cursor.last_positions.len) * 0.9))

		pos := danser_cursor.last_positions[i].apply_origin(danser_cursor.origin, size)

		arg.ctx.draw_image_with_config(context.DrawImageConfig{
			img: &danser_cursor.textures[1]
			img_id: danser_cursor.textures[1].id
			img_rect: gg.Rect{
				x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x)
				y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y)
				width: f32(size.x * x.resolution.playfield_scale)
				height: f32(size.y * x.resolution.playfield_scale)
			}
			color: danser_cursor.color
			effect: .add
		})
	}

	// Cursor
	pos := danser_cursor.position.apply_origin(danser_cursor.origin, danser_cursor.size)

	arg.ctx.draw_image_with_config(context.DrawImageConfig{
		img: &danser_cursor.textures[0]
		img_id: danser_cursor.textures[0].id
		img_rect: gg.Rect{
			x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x)
			y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y)
			width: f32(danser_cursor.size.x * x.resolution.playfield_scale)
			height: f32(danser_cursor.size.y * x.resolution.playfield_scale)
		}
		effect: .add
		color: gx.white
	})
}

pub fn (mut danser_cursor DanserCursor) update(update_time f64) {
	danser_cursor.Sprite.update(update_time)

	delta := update_time - danser_cursor.last_updated_time

	// Smooth trail
	if delta > 0.0 {
		points := int((danser_cursor.position.distance(danser_cursor.last_position)) * 2.0)

		danser_cursor.last_positions << danser_cursor.last_position

		for i := 1; i < points; i++ {
			danser_cursor.last_positions << danser_cursor.position.sub(danser_cursor.last_position).scale(f64(i) / f64(points)).add(danser_cursor.last_position)
		}

		times := int(danser_cursor.last_positions.len / (6.0 * (60.0 / delta)) + 1)

		if danser_cursor.last_positions.len > 0 {
			if times < danser_cursor.last_positions.len {
				danser_cursor.last_positions = danser_cursor.last_positions[times..]
			} else {
				// NOTE: This might not be the best way to do this
				unsafe {
					danser_cursor.last_positions.free()
				}
				danser_cursor.last_positions = []vector.Vector2[f64]{}
			}
		}
	}

	danser_cursor.last_position = danser_cursor.position
	danser_cursor.last_updated_time = update_time
}

// Factory
pub fn DanserCursor.create() &DanserCursor {
	mut cursor := &DanserCursor{
		always_visible: true
		textures: [
			skin.get_texture('cursor'),
			skin.get_texture('cursor-top'),
			skin.get_texture('cursortrailfx'),
		]
	}

	cursor.add_transform(
		typ: .scale_factor
		time: time2.Time{0, 0}
		before: [settings.global.gameplay.skin.cursor.size]
	)

	cursor.reset_size_based_on_texture()
	cursor.reset_attributes_based_on_transforms()

	cursor.textures = cursor.textures[1..]

	return cursor
}
