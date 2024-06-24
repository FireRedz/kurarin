module graphic

/*
	osu! slider renderer pipeline

	reference:
		- danser
		- mcosu
		- osu! 2016
*/
import core.common.settings
import core.osu.x
import math
import sokol.gfx
import sokol.sgl
import sokol.sapp
import framework.logging
import framework.math.vector
import framework.math.time

#flag -I @VMODROOT/
#include "../assets/osu/shaders/slider.h"

fn C.osu_slider_shader_desc(gfx.Backend) &gfx.ShaderDesc

pub const used_import = 0
pub const global_renderer = &SliderRenderer{}

@[manualfree]
pub struct SliderRendererAttr {
pub mut:
	cs                   f64
	length               f64
	points               []vector.Vector2[f64]
	vertices             []f32
	colors               []f32 // [3]Body [3]Border [3]BorderWidth, Style, Unused
	uniform              gfx.Range
	bindings             gfx.Bindings
	has_been_initialized bool
}

pub struct SliderRenderer {
mut:
	quality              int = 50 // anything >= 3 is fine
	has_been_initialized bool
pub mut:
	shader         gfx.Shader
	pip            gfx.Pipeline
	pass           gfx.Attachments
	pass_action    gfx.PassAction
	pass_action2   gfx.PassAction
	gradient       gfx.Image
	uniform        gfx.Range
	color_img      gfx.Image
	depth_img      gfx.Image
	uniform_values []f32 //
}

// Boost scaling thingy
pub fn update_boost_level(boost f32) {
	unsafe {
		mut g_render := graphic.global_renderer
		g_render.uniform_values[16] = boost
	}
}

// Maker
pub fn make_circle_vertices(position vector.Vector2[f64], cs f64) []vector.Vector2[f64] {
	mut points := []vector.Vector2[f64]{}
	points << position

	for i := 0; i < graphic.global_renderer.quality; i++ {
		points << vector.new_vec_rad(f64(i) / f64(graphic.global_renderer.quality) * 2.0 * math.pi,
			cs).add_normal(position.x, position.y)
	}

	points << points[1]

	return points
}

pub fn make_slider_renderer_attr(cs f64, points []vector.Vector2[f64], pixel_length f64) &SliderRendererAttr {
	mut attr := &SliderRendererAttr{}

	// Attributes
	attr.cs = cs
	attr.points = points
	attr.length = pixel_length

	// Color uniform
	attr.colors = []f32{}
	attr.colors << [
		f32(0.0),
		f32(0.0),
		f32(0.0),
		1.0, // Body
		f32(1.0),
		f32(1.0),
		f32(1.0),
		1.0, // Border
		f32(1.0),
		f32(1.0),
		f32(0.0),
		1.0, // Width, Style, Unused
	] // ignore the 4th 1.0's , some fucked up shit with sokol or v idek

	// Settings: Width, Style
	attr.colors[8] = f32(settings.global.gameplay.hitobjects.slider_width)
	attr.colors[9] = f32(settings.global.gameplay.hitobjects.slider_lazer_style)

	attr.uniform = gfx.Range{
		ptr: attr.colors.data
		size: usize(attr.colors.len * int(sizeof(f32)))
	}

	return attr
}

pub fn (mut attr SliderRendererAttr) generate_vertices() {
	if attr.has_been_initialized {
		return
	}

	attr.vertices = []f32{} // len: int(attr.length * 30 * 24)}

	// Make the fuckng verticds sss
	for _, v in attr.points {
		tab := make_circle_vertices(v, attr.cs)
		for j, _ in tab {
			if j >= 2 {
				p1, p2, p3 := &tab[j - 1], &tab[j], &tab[0]
				// Format
				// Position [vec3], Centre [vec3], TextureCoord [vec2]
				attr.vertices << [
					f32(p1.x),
					f32(p1.y),
					1.0,
					f32(p3.x),
					f32(p3.y),
					0.0,
					0.0,
					0.0,
					f32(p2.x),
					f32(p2.y),
					1.0,
					f32(p3.x),
					f32(p3.y),
					0.0,
					0.0,
					0.0,
					f32(p3.x),
					f32(p3.y),
					0.0,
					f32(p3.x),
					f32(p3.y),
					0.0,
					1.0,
					0.0,
				]
			}
		}
	}

	// // Test shader vertices
	// attr.vertices = [
	// 	// Positions				// Colors
	// 	f32(-.5), -.5, .0,			1.0, .0, .0,
	// 	.5, -.5, .0,				.0, 1.0, .0,
	// 	.0, .5, .0,					.0, .0, 1.0,
	// ]
}

pub fn (mut attr SliderRendererAttr) bind_slider() {
	if attr.vertices.len == 0 {
		// Something went wrong or the slider is just straitght up retadred
		return
	}

	// Bind the shit
	attr.bindings.vertex_buffers[0] = gfx.make_buffer(&gfx.BufferDesc{
		size: usize(attr.vertices.len * int(sizeof(f32)))
		// data: gfx.Range{
		// 	ptr: attr.vertices.data
		// 	size: usize(attr.vertices.len * int(sizeof(f32)))
		// }
		label: 'SliderBinding'.str
		usage: .dynamic
	})

	C.sg_update_buffer(&attr.bindings.vertex_buffers[0], &gfx.Range{
		ptr: attr.vertices.data
		size: usize(attr.vertices.len * int(sizeof(f32)))
	})

	// Failed to create vertex_buffers
	// if attr.bindings.vertex_buffers[0].id == 0 {
	// TODO: Fix this
	if false {
		logging.error('Failed to bind vertex buffers')
		return
	}

	// Done
	attr.has_been_initialized = true
}

// Draw
pub fn (mut attr SliderRendererAttr) draw_slider(alpha f64, colors []f64) {
	if !graphic.global_renderer.has_been_initialized {
		panic('global_renderer.has_been_initialized == False; This should not happen.')
	}

	if !attr.has_been_initialized {
		attr.bind_slider()
		return
	}

	// Fuck around with the colors
	// Literally copy-pasted from mcosu lmaooo credit to mckay
	if settings.global.gameplay.hitobjects.rainbow_slider {
		current_time := time.global.time / 100.0
		attr.colors[0] = f32(math.sin(0.3 * current_time + 0 + 10) * 127 + 128) / 255
		attr.colors[1] = f32(math.sin(0.3 * current_time + 2 + 10) * 127 + 128) / 255
		attr.colors[2] = f32(math.sin(0.3 * current_time + 4 + 10) * 127 + 128) / 255

		attr.colors[4] = f32(math.sin(0.3 * current_time * 1.5 + 0 + 10) * 127 + 128) / 255
		attr.colors[5] = f32(math.sin(0.3 * current_time * 1.5 + 2 + 10) * 127 + 128) / 255
		attr.colors[6] = f32(math.sin(0.3 * current_time * 1.5 + 4 + 10) * 127 + 128) / 255
	}

	// Body color
	if settings.global.gameplay.hitobjects.slider_body_use_border_color {
		attr.colors[0] = f32(colors[0] / 255.0 / 1.5)
		attr.colors[1] = f32(colors[1] / 255.0 / 1.5)
		attr.colors[2] = f32(colors[2] / 255.0 / 1.5)
	}

	// Border Color
	attr.colors[4] = f32(colors[0] / 255.0)
	attr.colors[5] = f32(colors[1] / 255.0)
	attr.colors[6] = f32(colors[2] / 255.0)

	// FIXME: This is janky asf lmao but it works
	// vfmt off
	gfx.begin_pass(attachments: graphic.global_renderer.pass, action: graphic.global_renderer.pass_action2)
		gfx.apply_pipeline(graphic.global_renderer.pip)
		gfx.apply_bindings(&attr.bindings)
		gfx.apply_uniforms(.vs, C.SLOT_vs_uniform, graphic.global_renderer.uniform)
		gfx.apply_uniforms(.fs, C.SLOT_fs_uniform, attr.uniform)
			gfx.draw(0, attr.vertices.len, 1)
		gfx.end_pass()
	gfx.commit()

	gfx.begin_pass(sapp.create_default_pass(graphic.global_renderer.pass_action))
		sgl.enable_texture()
		sgl.texture(graphic.global_renderer.color_img, gfx.Sampler{})
		sgl.c4b(255, 255, 255, u8(255 - (255 * alpha)))
		sgl.begin_quads()
			sgl.v3f_t2f(0, 0, 1, 0, 1)
			sgl.v3f_t2f(int(settings.global.window.width), 0, 1, 1, 1)
			sgl.v3f_t2f(int(settings.global.window.width), int(settings.global.window.height), 1, 1, 0)
			sgl.v3f_t2f(0, int(settings.global.window.height), 1, 0, 0)
		sgl.end()
	sgl.disable_texture()
		sgl.draw()
	gfx.end_pass()
	gfx.commit()
	// vfmt on
}

pub fn (mut attr SliderRendererAttr) free() {
	// Free shit
	if !attr.has_been_initialized {
		return
	}

	for mut buffer in attr.bindings.vertex_buffers {
		gfx.destroy_buffer(&buffer)
	}

	unsafe {
		attr.vertices.clear()
		attr.points.clear()

		attr.vertices.free()
		attr.points.free()
	}
}

// Init
pub fn init_slider_renderer() {
	if graphic.global_renderer.has_been_initialized {
		logging.warn('Slider renderer already initialized!!')
		return
	}

	// Start
	logging.info('Initializing slider renderer!')

	mut renderer := unsafe { graphic.global_renderer }

	// Normal slider shader
	renderer.shader = gfx.make_shader(C.osu_slider_shader_desc(gfx.query_backend()))

	// Make pipeline
	mut pipeline_desc := &gfx.PipelineDesc{
		shader: renderer.shader
		depth: gfx.DepthState{
			pixel_format: .depth
			compare: .less
			write_enabled: true
		}
	}

	// Pipeline blending (for slider to appear correctly)
	pipeline_desc.colors[0].pixel_format = .rgba8
	pipeline_desc.colors[0].blend.enabled = false
	pipeline_desc.colors[0].blend.op_rgb = .add
	pipeline_desc.colors[0].blend.src_factor_rgb = .src_alpha
	pipeline_desc.colors[0].blend.dst_factor_rgb = .one_minus_src_alpha

	// Pipeline attribute
	pipeline_desc.layout.attrs[C.ATTR_vs_in_position].format = .float3 // pos
	pipeline_desc.layout.attrs[C.ATTR_vs_centre].format = .float3 // centre
	pipeline_desc.layout.attrs[C.ATTR_vs_texture_coord].format = .float2 // texture coord
	renderer.pip = gfx.make_pipeline(pipeline_desc)

	// Color and Depth buffer
	mut img_desc := gfx.ImageDesc{
		render_target: true
		width: int(settings.global.window.width)
		height: int(settings.global.window.height)
		pixel_format: .rgba8
		label: 'ColorBuffer'.str
	}
	renderer.color_img = gfx.make_image(&img_desc)
	img_desc.pixel_format = .depth
	img_desc.label = 'DepthBuffer'.str
	renderer.depth_img = gfx.make_image(&img_desc)

	// Pass
	mut offscreen_pass_desc := gfx.AttachmentsDesc{
		label: 'offscreen-pass'.str
	}
	offscreen_pass_desc.colors[0].image = renderer.color_img
	offscreen_pass_desc.depth_stencil.image = renderer.depth_img
	renderer.pass = gfx.make_attachments(&offscreen_pass_desc)

	// Pass action
	renderer.pass_action.colors[0] = gfx.ColorAttachmentAction{
		load_action: .dontcare
		clear_value: gfx.Color{1.0, 1.0, 1.0, 1.0}
	}

	renderer.pass_action2.colors[0] = gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{1.0, 1.0, 1.0, 0.0}
	}

	// Uniform (projection and slider scale)
	for col in 0 .. 4 {
		for row in 0 .. 4 {
			renderer.uniform_values << x.resolution.projection.get_f(col, row)
		}
	}

	renderer.uniform_values << [
		f32(1.0),
		0.0,
		0.0,
		0.0,
	]

	renderer.uniform = gfx.Range{
		ptr: renderer.uniform_values.data
		size: usize(renderer.uniform_values.len * int(sizeof(f32)))
	}

	// Done
	renderer.has_been_initialized = true
	logging.info('Done initializing slider renderer!')
}
