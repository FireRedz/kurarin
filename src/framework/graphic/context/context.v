module context

import gg
import sokol.sgl
import sokol.sapp
import mohamedlt.sokolgp
import framework.logging
import framework.math.vector

pub struct Context {
	gg.Context
mut:
	has_gp_begin bool
pub mut:
	texture_not_found gg.Image
}

pub fn (mut context Context) begin_gp() {
	if !context.has_gp_begin {
		width := sapp.width()
		height := sapp.height()

		sokolgp.begin(width, height)
		sokolgp.viewport(0, 0, width, height)

		context.has_gp_begin = true
	}
}

pub fn (mut context Context) end_gp() {
	sokolgp.flush()
	sokolgp.end()

	context.has_gp_begin = false
}

// create_image creates an image from the path specified, returns default texture if something went wrong.
pub fn (mut context Context) create_image(path string) gg.Image {
	if isnil(context.texture_not_found.data) {
		logging.info('Default texture not loaded, loading it.')

		if t_not_found := context.Context.create_image('assets/common/textures/default.png') {
			logging.info('Default texture loaded.')
			context.texture_not_found = t_not_found
		} else {
			logging.warn('Failed to load default texture, shit will look retarded.')
		}
	}

	return context.Context.create_image(path) or {
		logging.warn('Failed to create image!')
		return context.texture_not_found
	}
}

pub struct DrawImageConfig {
	gg.DrawImageConfig
pub:
	rotate f32
	origin vector.Origin = vector.centre
}

// draw_image_with_config is a reimplementation of the same function from gg's
// but with origin types
pub fn (ctx &Context) draw_image_with_config(config DrawImageConfig) {
	id := if !isnil(config.img) { config.img.id } else { config.img_id }

	if id >= ctx.image_cache.len {
		eprintln('gg: draw_image() bad img id ${id} (img cache len = ${ctx.image_cache.len})')
		return
	}

	img := &ctx.image_cache[id]
	if !img.simg_ok {
		return
	}

	mut img_rect := config.img_rect
	if img_rect.width == 0 && img_rect.height == 0 {
		img_rect = gg.Rect{img_rect.x, img_rect.y, img.width, img.height}
	}

	mut part_rect := config.part_rect
	if part_rect.width == 0 && part_rect.height == 0 {
		part_rect = gg.Rect{part_rect.x, part_rect.y, img.width, img.height}
	}

	u0 := part_rect.x / img.width
	v0 := part_rect.y / img.height
	u1 := (part_rect.x + part_rect.width) / img.width
	v1 := (part_rect.y + part_rect.height) / img.height
	x0 := img_rect.x * ctx.scale
	y0 := img_rect.y * ctx.scale
	x1 := (img_rect.x + img_rect.width) * ctx.scale
	mut y1 := (img_rect.y + img_rect.height) * ctx.scale
	if img_rect.height == 0 {
		scale := f32(img.width) / f32(img_rect.width)
		y1 = f32(img_rect.y + int(f32(img.height) / scale)) * ctx.scale
	}

	flip_x := config.flip_x
	flip_y := config.flip_y

	mut u0f := if !flip_x { u0 } else { u1 }
	mut u1f := if !flip_x { u1 } else { u0 }
	mut v0f := if !flip_y { v0 } else { v1 }
	mut v1f := if !flip_y { v1 } else { v0 }

	match config.effect {
		.add {
			sgl.load_pipeline(ctx.pipeline.add)
		}
		.alpha {
			sgl.load_pipeline(ctx.pipeline.alpha)
		}
	}

	sgl.enable_texture()
	sgl.texture(img.simg)

	if config.rotate != 0 {
		width := img_rect.width * ctx.scale
		height := (if img_rect.height > 0 { img_rect.height } else { img.height }) * ctx.scale

		sgl.push_matrix()

		// NOTE: This is wrong somehow.
		// // Origin offsets
		// mut offset_x := x0
		// mut offset_y := y0

		// match config.origin.typ {
		// 	.top_left {}
		// 	.top_centre {
		// 		offset_x = x0 + (width / 2.0)
		// 		offset_y = y0 - height
		// 	}
		// 	.top_right {
		// 		offset_x = x0 + width
		// 		offset_y = y0 - height
		// 	}
		// 	.centre_left {
		// 		offset_x = x0
		// 		offset_y = y0 + (height / 2)
		// 	}
		// 	.centre {
		// 		offset_x = x0 + (width / 2)
		// 		offset_y = y0 + (height / 2)
		// 	}
		// 	.centre_right {
		// 		offset_x = x0 + width
		// 		offset_y = y0 + (height / 2)
		// 	}
		// 	.bottom_left {
		// 		offset_x = x0
		// 		offset_y = y0 + height
		// 	}
		// 	.bottom_centre {
		// 		offset_x = x0 + (width / 2)
		// 		offset_y = y0 + height
		// 	}
		// 	.bottom_right {
		// 		offset_x = x0 + width
		// 		offset_y = y0 + height
		// 	}
		// }

		// sgl.translate(offset_x, offset_y, 0)
		// sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
		// sgl.translate(-offset_x, -offset_y, 0)

		// NOTE: This is awful, but it works.
		match config.origin.typ {
			.top_left {
				sgl.translate(x0, y0, 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0, -y0, 0)
			}
			.top_centre {
				sgl.translate(x0 + (width / 2), y0 - height, 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0 - (width / 2), -y0, 0)
			}
			.top_right {
				sgl.translate(x0 + width, y0 - height, 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0 - width, -y0, 0)
			}
			.centre_left {
				sgl.translate(x0, y0 + (height / 2), 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0, -y0 - (height / 2), 0)
			}
			.centre {
				sgl.translate(x0 + (width / 2), y0 + (height / 2), 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0 - (width / 2), -y0 - (height / 2), 0)
			}
			.centre_right {
				sgl.translate(x0 + width, y0 + (height / 2), 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0 - width, -y0 - (height / 2), 0)
			}
			.bottom_left {
				sgl.translate(x0, y0 + height, 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0, -y0 - height, 0)
			}
			.bottom_centre {
				sgl.translate(x0 + (width / 2), y0 + height, 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0 - (width / 2), -y0 - height, 0)
			}
			.bottom_right {
				sgl.translate(x0 + width, y0 + height, 0)
				sgl.rotate(sgl.rad(-config.rotate), 0, 0, 1)
				sgl.translate(-x0 - width, -y0 - height, 0)
			}
		}
	}

	sgl.begin_quads()
	sgl.c4b(config.color.r, config.color.g, config.color.b, config.color.a)
	sgl.v3f_t2f(x0, y0, config.z, u0f, v0f)
	sgl.v3f_t2f(x1, y0, config.z, u1f, v0f)
	sgl.v3f_t2f(x1, y1, config.z, u1f, v1f)
	sgl.v3f_t2f(x0, y1, config.z, u0f, v1f)
	sgl.end()

	if config.rotate != 0 {
		sgl.pop_matrix()
	}

	sgl.disable_texture()

	// println("========")
	// println("${img_rect.width} ${img_rect.height} | ${img_rect.x} ${img_rect.y}")
	// println("${x0} ${y0} ${u0f} ${v0f}")
	// println("${x1} ${y0} ${u1f} ${v0f}")
	// println("${x1} ${y1} ${u1f} ${v1f}")
	// println("${x0} ${y1} ${u0f} ${v1f}")
	// println("========")
}

pub fn (ctx &Context) draw_image_batch_with_config(config DrawImageConfig) {
	id := if !isnil(config.img) { config.img.id } else { config.img_id }

	if id >= ctx.image_cache.len {
		eprintln('gg: draw_image() bad img id ${id} (img cache len = ${ctx.image_cache.len})')
		return
	}

	img := &ctx.image_cache[id]

	if !img.simg_ok {
		return
	}

	mut img_rect := config.img_rect
	if img_rect.width == 0 && img_rect.height == 0 {
		img_rect = gg.Rect{img_rect.x, img_rect.y, img.width, img.height}
	}

	mut part_rect := config.part_rect
	if part_rect.width == 0 && part_rect.height == 0 {
		part_rect = gg.Rect{part_rect.x, part_rect.y, img.width, img.height}
	}

	x0 := img_rect.x * ctx.scale
	y0 := img_rect.y * ctx.scale

	// vfmt off
	match config.effect {
		.add {
			sokolgp.set_blend_mode(.sgp_blendmode_add)
		}
		.alpha {
			sokolgp.set_blend_mode(.sgp_blendmode_blend)
		}
	}


	if config.rotate != 0 {
		width := img_rect.width * ctx.scale
		height := (if img_rect.height > 0 { img_rect.height } else { img.height }) * ctx.scale

		sokolgp.push_transform()

		// NOTE: This is awful, but it works.
		match config.origin.typ {
			.top_left {
				sokolgp.translate(x0, y0)
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0, -y0)
			}
			.top_centre {
				sokolgp.translate(x0 + (width / 2), y0 - height)
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0 - (width / 2), -y0)
			}
			.top_right {
				sokolgp.translate(x0 + width, y0 - height)
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0 - width, -y0)
			}
			.centre_left {
				sokolgp.translate(x0, y0 + (height / 2))
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0, -y0 - (height / 2))
			}
			.centre {
				sokolgp.translate(x0 + (width / 2), y0 + (height / 2))
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0 - (width / 2), -y0 - (height / 2))
			}
			.centre_right {
				sokolgp.translate(x0 + width, y0 + (height / 2))
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0 - width, -y0 - (height / 2))
			}
			.bottom_left {
				sokolgp.translate(x0, y0 + height)
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0, -y0 - height)
			}
			.bottom_centre {
				sokolgp.translate(x0 + (width / 2), y0 + height)
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0 - (width / 2), -y0 - height)
			}
			.bottom_right {
				sokolgp.translate(x0 + width, y0 + height)
				sokolgp.rotate(sgl.rad(-config.rotate))
				sokolgp.translate(-x0 - width, -y0 - height)
			}
		}
	}

	sokolgp.set_image(0, img.simg)

	sokolgp.set_color(
		f32(config.color.r) / 255.0, 
		f32(config.color.g) / 255.0, 
		f32(config.color.b) / 255.0,
		f32(config.color.a) / 255.0
	)

	sokolgp.draw_textured_rect(x0, y0, img_rect.width, img_rect.height)

	if config.rotate != 0 {
		sokolgp.pop_transform()
	}

	// vfmt on
}
