module graphic

/*
	THE ONE AND ONLY

	SLIDER RENDER RER

	I FUCKING HATE SLIDER RENDER RER
*/

import library.stbi
import math

import sokol
import sokol.gfx
// import sokol.sgl // TODO: use sokol's wrapper structs instead of C's 

import framework.logging
import framework.math.vector

#flag -I @VMODROOT/
#include "assets/shaders/slider.h"
#include "assets/shaders/test.h"

fn C.fuck_shader_desc(gfx.Backend) &C.sg_shader_desc
fn C.test_shader_desc(gfx.Backend) &C.sg_shader_desc

pub const (
	used_import = gfx.used_import + sokol.used_import
	global_renderer = &SliderRenderer{}
	use_test_shader = false
)

pub struct SliderRendererAttr {
	pub mut:
		cs       f64
		length   f64
		points   []vector.Vector2
		vertices []f32
		bindings C.sg_bindings
		has_been_initialized bool
}

pub struct SliderRenderer {
	mut:
		quality              int  = 30 // anything >= 3 is fine
		has_been_initialized bool

	pub mut:
		shader   C.sg_shader
		pip      C.sg_pipeline
		pass     C.sg_pass_action
		gradient C.sg_image
}


// Maker
pub fn make_circle_vertices(position vector.Vector2, cs f64) []vector.Vector2 {
	mut points := []vector.Vector2{}
	points << position

	for i := 0; i < global_renderer.quality; i++ {
		points << vector.new_vec_rad(
			f64(i)/f64(global_renderer.quality)*2.0*math.pi,
			cs
		).add_normal(position.x, position.y)
	}

	points << points[1]

	return points
}

pub fn make_slider_renderer_attr(cs f64, points []vector.Vector2, pixel_length f64) &SliderRendererAttr {
	mut attr := &SliderRendererAttr{}

	// Attributes
	attr.cs = cs
	attr.points = points
	attr.length = pixel_length

	return attr

}

pub fn (mut attr SliderRendererAttr) make_vertices() {
	/*
		for whatevrer reason i cant make buffer on gothread/coroutine, only on draw calls bruh
	*/

	if attr.has_been_initialized { return }

	attr.vertices = []f32{}//len: int(attr.length * 30 * 24)}

	// Make the fuckng verticds sss
	for _, v in attr.points {
		tab := make_circle_vertices(v, attr.cs)
		for j, _ in tab {
			if j >= 2 {
				p1, p2, p3 := tab[j - 1], tab[j], tab[0]
				// Format
				// Position [vec3], Centre [vec3], TextureCoord [vec2]
				attr.vertices << &[
					f32(p1.x), f32(p1.y), 1.0,
					f32(p3.x), f32(p3.y), 0.0, 
					0.0, 0.0, 

					f32(p2.x), f32(p2.y), 1.0, 
					f32(p3.x), f32(p3.y), 0.0, 
					0.0, 0.0, 
					
					f32(p3.x), f32(p3.y), 0.0, 
					f32(p3.x), f32(p3.y), 0.0, 
					1.0, 0.0
				]

				// 1
				// attr.vertices[(24 * i) + 0] = f32(p1.x)
				// attr.vertices[(24 * i) + 1] = f32(p1.y)
				// attr.vertices[(24 * i) + 2] = 1.0

				// attr.vertices[(24 * i) + 3] = f32(p3.x)
				// attr.vertices[(24 * i) + 4] = f32(p3.y)
				// attr.vertices[(24 * i) + 5] = 0.0

				// attr.vertices[(24 * i) + 6] = 0.0
				// attr.vertices[(24 * i) + 7] = 0.0

				// // 2
				// attr.vertices[(24 * i) + 8] = f32(p2.x)
				// attr.vertices[(24 * i) + 9] = f32(p2.y)
				// attr.vertices[(24 * i) + 10] = 1.0

				// attr.vertices[(24 * i) + 11] = f32(p3.x)
				// attr.vertices[(24 * i) + 12] = f32(p3.y)
				// attr.vertices[(24 * i) + 13] = 0.0

				// attr.vertices[(24 * i) + 14] = 0.0
				// attr.vertices[(24 * i) + 15] = 0.0

				// // 3
				// attr.vertices[(24 * i) + 16] = f32(p3.x)
				// attr.vertices[(24 * i) + 17] = f32(p3.y)
				// attr.vertices[(24 * i) + 18] = 0.0

				// attr.vertices[(24 * i) + 19] = f32(p3.x)
				// attr.vertices[(24 * i) + 20] = f32(p3.y)
				// attr.vertices[(24 * i) + 21] = 0.0

				// attr.vertices[(24 * i) + 22] = 1.0
				// attr.vertices[(24 * i) + 23] = 0.0
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

	// Bind the shit
	attr.bindings.vertex_buffers[0] = C.sg_make_buffer(&C.sg_buffer_desc{
		size: usize(attr.vertices.len * int(sizeof(f32))),
		data: C.sg_range{
			ptr: attr.vertices.data,
			size: usize(attr.vertices.len * int(sizeof(f32)))
		}
		label: &byte(0),
	})

	// Failed to create vertex_buffers
	// if attr.bindings.vertex_buffers[0].id == 0 {
	if false {
		logging.error("Failed to bind vertex buffers")
		return 
	}

	// Done
	attr.has_been_initialized = true
}

pub fn (mut attr SliderRendererAttr) update_vertex_progress(start int, end int) {
	// TODO: come back to this
	// if !attr.has_been_initialized { 
	// 	attr.make_vertices()
	// }

	// if attr.vertices[start * 30 * 24 .. end * 30 * 24].len != 0 {	
		// C.sg_update_buffer(&attr.bindings.vertex_buffers[0], &C.sg_range{
			// ptr: &attr.vertices[start * 30 * 24 .. (end * 30 * 24) - 1][0],
			// size: usize((attr.vertices[start * 30 * 24 .. end * 30 * 24].len) * int(sizeof(f32)))
			// ptr: attr.vertices.data,
			// size: usize(attr.vertices.len * int(sizeof(f32)))
		// })	
	// }
}

// Draw
pub fn (mut attr SliderRendererAttr) draw_slider(alpha f64) {
	if !global_renderer.has_been_initialized { panic("global_renderer.has_been_initialized == False; This should not happen.") }
	if !attr.has_been_initialized { 
		attr.make_vertices()
		return
	}

	gfx.apply_pipeline(global_renderer.pip)
	gfx.apply_bindings(&attr.bindings)
	gfx.draw(0, attr.vertices.len, 1)
}

pub fn (mut attr SliderRendererAttr) free() {
	// Free shit
	if !attr.has_been_initialized { return }

	for mut buffer in attr.bindings.vertex_buffers {
		buffer.free()
	}

	unsafe {
		attr.vertices.free()
		attr.points.free()
	}
}


// Init
pub fn init_slider_renderer() {
	// Start
	logging.info("Initializing slider renderer!")

	mut renderer := global_renderer

	// Normal slider shader
	renderer.shader = C.sg_make_shader(
		C.fuck_shader_desc(
			C.sg_query_backend()
		)
	)

	// Make pipeline
	mut pipeline_desc := &C.sg_pipeline_desc{
		shader: renderer.shader,
		depth: C.sg_depth_state{
			compare: .less,
			write_enabled: true
		}
	}

	// Pipeline blending (for slider to appear correctly, well almost.)
	pipeline_desc.colors[0].blend.enabled = true
	pipeline_desc.colors[0].blend.op_rgb = .add
	pipeline_desc.colors[0].blend.src_factor_rgb = .src_alpha
	pipeline_desc.colors[0].blend.dst_factor_rgb = .one_minus_src_alpha


	// Pipeline attribute 
	pipeline_desc.layout.attrs[C.ATTR_vs_in_position].format = .float3 // pos
	pipeline_desc.layout.attrs[C.ATTR_vs_centre].format = .float3 // centre
	pipeline_desc.layout.attrs[C.ATTR_vs_texture_coord].format = .float2 // texture coord
	renderer.pip = C.sg_make_pipeline(pipeline_desc)

	// Slider texture
	stb_img := stbi.load("assets/textures/slider_gradient_stable.png") or { panic(err) }
	mut img_desc := C.sg_image_desc{
		width: stb_img.width,
		height: stb_img.height,
		num_mipmaps: 0,
		wrap_u: .clamp_to_edge,
		wrap_v: .clamp_to_edge,
		label: &byte(0),
		d3d11_texture: 0,
	}
	img_desc.data.subimage[0][0] = C.sg_range{
		ptr: stb_img.data,
		size: usize(stb_img.nr_channels * stb_img.width * stb_img.height)
	}
	renderer.gradient = C.sg_make_image(&img_desc)

	// // Test Shader
	// renderer.shader = C.sg_make_shader(
	// 	C.test_shader_desc(
	// 		C.sg_query_backend()
	// 	)
	// )

	// mut pipeline_desc := &C.sg_pipeline_desc{shader: renderer.shader}
	// pipeline_desc.layout.attrs[C.ATTR_vs_test_position].format = .float3
	// pipeline_desc.layout.attrs[C.ATTR_vs_test_color].format = .float3
	// renderer.pip = C.sg_make_pipeline(pipeline_desc)

	// Pass
	renderer.pass.colors[0] = C.sg_color_attachment_action{
		action: .dontcare,
		value: C.sg_color{0.0, 0.0, 0.0, 0.0}
	}

	// Done
	renderer.has_been_initialized = true
	logging.info("Done initializing slider renderer!")
}
