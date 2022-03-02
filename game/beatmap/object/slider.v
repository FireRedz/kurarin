module object

import library.gg
import math

import framework.graphic.sprite
import framework.math.vector
import framework.math.time
import framework.logging

import game.beatmap.difficulty
import game.beatmap.hitsystem
import game.beatmap.timing
import game.audio
import game.skin
import game.x

import curves
import graphic


pub struct Slider {
	HitObject

	pub mut:
		timing          timing.Timings
		hitcircle 		&Circle

		// Slider shit
		repeated        int
		pixel_length    f64
		duration        f64		
		points          []vector.Vector2
		curve           curves.SliderCurve

		// 
		slider_overlay_sprite &sprite.Sprite = &sprite.Sprite{}
		slider_b_sprite  	  &sprite.Sprite = &sprite.Sprite{}
		

		sprites         	  []&sprite.Sprite
		slider_renderer_attr  &graphic.SliderRendererAttr = voidptr(0)

		// Sample
		samples         []int
		sample_sets     []int
		addition_sets   []int // TODO

		// temp
		done             bool
		last_slider_time int
		last_time        f64

}

pub fn (mut slider Slider) set_combo_number(combo int) {
	slider.hitcircle.set_combo_number(combo)
}

pub fn (mut slider Slider) draw(arg sprite.CommonSpriteArgument) {
	slider.hitcircle.draw(arg)
	// Draw the easy stuff first
	for mut sprite in slider.sprites {
		if sprite.is_drawable_at(slider.last_time) {
			pos := sprite.position.sub(sprite.origin.multiply(x: sprite.size.x, y: sprite.size.y))
			arg.ctx.draw_image_with_config(gg.DrawImageConfig{
					img: sprite.get_texture(),
					img_id: sprite.get_texture().id,
					img_rect: gg.Rect{
						x: f32(pos.x * x.resolution.playfield_scale + x.resolution.offset.x),
						y: f32(pos.y * x.resolution.playfield_scale + x.resolution.offset.y),
						width: f32(sprite.size.x * x.resolution.playfield_scale),
						height: f32(sprite.size.y * x.resolution.playfield_scale)
					},
					color: sprite.color
			})
		}
	}

	mut once := false
	// Draw slider body following by slider.hitcircle and slider_overlay_sprite
	if slider.last_time <= slider.get_start_time() && slider.hitcircle.hitcircle.is_drawable_at(slider.last_time) && !once {
		slider.slider_renderer_attr.draw_slider(slider.hitcircle.hitcircle.color.a)
		once = true
	}
	
	if slider.last_time >= slider.get_start_time() && slider.slider_overlay_sprite.is_drawable_at(slider.last_time) && !once {
		slider.slider_renderer_attr.draw_slider(slider.slider_overlay_sprite.color.a)
		once = true
	}
}

pub fn (mut slider Slider) play_hitsound(index int) {
	mut sample := slider.samples[index]
	mut sample_set := slider.sample_sets[index]
	mut sample_index := slider.hitsound.custom_index
	
	point := slider.timing.get_point_at(slider.time.start + math.floor(index * slider.duration + 5))

	if sample_index == 0 {
		sample_index = point.sample_index
	}

	if sample_set == 0 {
		sample_set = slider.hitsound.sample_set

		if sample_set == 0 {
			sample_set = point.sample_set
		}
	}

	audio.play_sample(
		sample_set, 
		0,
		sample,
		sample_index
	)
}

pub fn (mut slider Slider) update(time f64) bool {
	slider.last_time = time

	slider.hitcircle.update(time)

	for mut sprite in slider.sprites {
		sprite.update(time)
	}

	// Hitsounds
	if time >= slider.time.start && time <= slider.time.end {
		times := int(((time - slider.time.start) / slider.duration) + 1)

		// Dont play the first hitsound (as we already play it with hitcircle)
		if times != 1 && slider.last_slider_time != times {
			slider.hitsystem.increment_combo()
			slider.play_hitsound(times - 1)
			slider.last_slider_time = times
		}

		return false
	}


	// Last hit
	if time >= slider.time.end && !slider.done {
		slider.hitsystem.increment_combo()
		slider.play_hitsound(int(slider.repeated))
		slider.done = true

		return true
	}

	return false
}

pub fn (mut slider Slider) post_update(time f64) {
	logging.debug("Freeing slider.")
	slider.slider_renderer_attr.free()
}

pub fn (mut slider Slider) set_timing(t timing.Timings) {
	slider.timing = t
	slider.hitcircle.set_timing(t)

	// Slider data
	slider.repeated = slider.data[6].int()
	slider.pixel_length = slider.data[7].f64()

	// Duration per one round (duration*n if its a reverse slider)
	slider.duration = slider.timing.get_point_at(slider.time.start).get_beat_length() * slider.pixel_length / (100 * slider.timing.slider_multiplier)
	slider.time.end += slider.duration * f64(slider.repeated)

	// Samples
	slider.samples = []int{len: int(slider.repeated) + 1}
	slider.sample_sets = []int{len: int(slider.repeated) + 1}
	slider.addition_sets = []int{len: int(slider.repeated) + 1}

	// Sample
	if slider.data.len > 8 {
		data := slider.data[8].split("|")
		for i, v in data {
			slider.samples[i] = v.int()
		}
	}

	// Sets
	if slider.data.len > 9 {
		data := slider.data[9].split("|")
		for i, v in data {
			items := v.split(":")
			slider.sample_sets[i] = items[0].int()
			slider.addition_sets[i] = items[1].int()
		}
	}
}

pub fn (mut slider Slider) set_hitsystem(h &hitsystem.HitSystem) {
	slider.hitsystem = unsafe { h }
	slider.hitcircle.set_hitsystem(h)
}

pub fn (mut slider Slider) generate_slider_points() {
	logging.debug("Generating slider path!")

	slider_points_raw := slider.data[5].split("|")
	slider_type := slider_points_raw[0]

	mut slider_points := []vector.Vector2{}
	slider_points << slider.position
	slider_points << slider_points_raw[1..].map(fn (data string) vector.Vector2 {
		items := data.split(":")
		return vector.Vector2{items[0].f64(), items[1].f64()}
	})

	
	// oh god
	slider.curve = curves.new_slider_curve(slider_type, slider_points)
	slider.end_position = slider.curve.point_at(slider.repeated % 2)

	// Done
	logging.debug("Done generating slider path!")
}

pub fn (mut slider Slider) generate_slider_follow_circles() {
	size_ratio := f64((slider.diff.circle_radius * 1.05 * 2) / 128)

	// not poggers
	slider.slider_overlay_sprite.textures << skin.get_texture("sliderfollowcircle")
	slider.slider_b_sprite.textures << skin.get_texture("sliderb")

	mut slider_sprites := []&sprite.Sprite{}
	slider_sprites << slider.slider_overlay_sprite
	slider_sprites << slider.slider_b_sprite

	// Color
	slider.slider_b_sprite.add_transform(typ: .color, time: time.Time{slider.time.start, slider.time.start}, before: slider.color)

	// The thing taht slider circle does
	slider.slider_overlay_sprite.add_transform(typ: .scale_factor, time: time.Time{slider.time.end, slider.time.end + 160.0}, before: [size_ratio], after: [size_ratio * 0.75])

	// Movement
	mut last_position := slider.position

	for i, mut sprite in slider_sprites {
		// Movement
		offset := 16

		for temp_time := int(slider.time.start); temp_time <= int(slider.time.end) + offset; temp_time += offset {
			times := int(((temp_time - slider.time.start) / slider.duration) + 1)
			t_time := (f64(temp_time) - slider.time.start - (times - 1) * slider.duration)
			rt := slider.pixel_length / slider.curve.length

			mut pos := vector.Vector2{}
			if (times % 2) == 1 {
				pos = slider.curve.point_at(rt * t_time / slider.duration)
				last_position = slider.curve.point_at(rt * (t_time - offset) / slider.duration)
			} else {
				pos = slider.curve.point_at((1.0 - t_time / slider.duration) * rt)
				last_position = slider.curve.point_at((1.0 - (t_time - offset) / slider.duration) * rt)
			}
			sprite.add_transform(typ: .move, time: time.Time{temp_time, temp_time + offset}, before: [last_position.x, last_position.y], after: [pos.x, pos.y])
		}

		// Just incase
		// sprite.add_transform(typ: .move, time: time.Time{slider.time.end - offset, slider.time.end}, before: [last_position.x, last_position.y], after: [slider.end_position.x, slider.end_position.y])

		// Fadeout
		sprite.add_transform(typ: .scale_factor, time: time.Time{slider.time.start, slider.time.start}, before: [size_ratio])

		// This is utterly retarded
		// 0 is slider_overlay
		// 1 is slider_b
		if i == 0 {
			sprite.add_transform(typ: .fade, time: time.Time{slider.time.end, slider.time.end + 160.0}, before: [255.0], after: [0.0])
		} else {
			sprite.add_transform(typ: .fade, time: time.Time{slider.time.end, slider.time.end + 16.0}, before: [255.0], after: [0.0])
		}
		
	
		// Done
		sprite.reset_size_based_on_texture()
		sprite.reset_attributes_based_on_transforms()
	}

	slider.sprites << slider.slider_overlay_sprite
	slider.sprites << slider.slider_b_sprite
}

pub fn (mut slider Slider) generate_slider_renderer() {
	slider.slider_renderer_attr = graphic.make_slider_renderer_attr(
		slider.diff.circle_radius, slider.get_slider_points()
	)
}

pub fn (mut slider Slider) get_slider_points() []vector.Vector2 {
	t0 := f64(2 / slider.pixel_length)
	rt := f64(slider.pixel_length) / slider.curve.length
	mut points := []vector.Vector2{len: int(slider.pixel_length / 2)}
	mut t := 0.0

	for i := 0; i < int(slider.pixel_length / 2); i++ {
		points[i] = slider.curve.point_at(f64(t) * f64(rt))
		t += t0
	}

	return points
}

pub fn (mut slider Slider) set_difficulty(diff difficulty.Difficulty) {
	slider.diff = diff
	slider.hitcircle.set_difficulty(diff)

	// Make points n shit
	slider.generate_slider_points()
	slider.generate_slider_follow_circles()
	slider.generate_slider_renderer()
}


pub fn make_slider(items []string) &Slider {
	mut hslider := &Slider{
		HitObject: common_parse(items, 10),
		hitcircle: make_circle(items)
	}

	return hslider
}
