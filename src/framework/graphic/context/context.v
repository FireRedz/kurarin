module context

import gg
import sokol.sgl
import sokol.gfx
import sokol.sapp
import framework.logging
import framework.math.vector

const invisible_pass = gfx.PassAction{
	colors: [
		gfx.ColorAttachmentAction{
			load_action: .dontcare
			clear_value: gfx.Color{1.0, 1.0, 1.0, 1.0}
		},
		gfx.ColorAttachmentAction{
			load_action: .dontcare
			clear_value: gfx.Color{1.0, 1.0, 1.0, 1.0}
		},
		gfx.ColorAttachmentAction{
			load_action: .dontcare
			clear_value: gfx.Color{1.0, 1.0, 1.0, 1.0}
		},
		gfx.ColorAttachmentAction{
			load_action: .dontcare
			clear_value: gfx.Color{1.0, 1.0, 1.0, 1.0}
		},
	]!
}

pub struct Context {
	gg.Context
mut:
	cache map[string]gg.Image
pub mut:
	texture_not_found gg.Image
}

pub fn Context.create(mut context gg.Context) &Context {
	mut ctx := &Context{
		Context: context
	}

	ctx.texture_not_found = ctx.Context.create_image('assets/common/textures/default.png') or {
		logging.error('Failed to load default texture, undefined behaviour inbound!')

		gg.Image{}
	}

	return ctx
}

// begin_gp ends sokol gp and gg context.
pub fn (mut ctx Context) end_short() {
	gfx.begin_pass(sapp.create_default_pass(context.invisible_pass))

	sgl.draw()
	gfx.end_pass()

	gfx.commit()
}

// create_image creates an image from the path specified, returns default texture if something went wrong.
pub fn (mut ctx Context) create_image(path string) gg.Image {
	if path !in ctx.cache {
		ctx.cache[path] = ctx.Context.create_image(path) or {
			logging.warn('Failed to create image!')
			return ctx.texture_not_found
		}
	}

	return ctx.cache[path] or { panic('[Context] Cache missed: This should never happen.') }
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
	sgl.texture(img.simg, gfx.Sampler{})

	if config.rotate != 0 {
		width := img_rect.width * ctx.scale
		height := (if img_rect.height > 0 { img_rect.height } else { img.height }) * ctx.scale

		sgl.push_matrix()

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
