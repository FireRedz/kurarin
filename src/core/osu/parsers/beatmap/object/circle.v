module object

// import framework.logging
import math
// import gg
import framework.math.time
import framework.math.easing
import framework.graphic.sprite
import core.common.settings
import core.osu.parsers.beatmap.difficulty
import core.osu.parsers.beatmap.timing
import core.osu.system.audio
import core.osu.system.skin
// import core.osu.x

const default_hitcircle_size = 128.0
const is_hidden = false

pub struct Circle {
	HitObject
pub mut:
	timing timing.Timings

	hitcircle        &sprite.Sprite       = &sprite.Sprite{}
	hitcircleoverlay &sprite.Sprite       = &sprite.Sprite{}
	approachcircle   &sprite.Sprite       = &sprite.Sprite{}
	combotext        &sprite.NumberSprite = unsafe { nil }

	sprites []sprite.ISprite
	diff    difficulty.Difficulty
	silent  bool

	sample int
	// temp shit
	last_time f64
	done      bool
	inherited bool
}

pub fn (mut circle Circle) draw(arg sprite.CommonSpriteArgument) {
	if settings.global.gameplay.hitobjects.rainbow_hitcircle {
		last_time := circle.last_time / 100.0
		circle.hitcircle.color.r = u8(f32(math.sin(0.3 * last_time + 0 + 1 * 1) * 127.0 + 128.0))
		circle.hitcircle.color.g = u8(f32(math.sin(0.3 * last_time + 2 + 1 * 1) * 127.0 + 128.0))
		circle.hitcircle.color.b = u8(f32(math.sin(0.3 * last_time + 4 + 1 * 1) * 127.0 + 128.0))

		circle.combotext.color = circle.hitcircle.color
		circle.approachcircle.color = circle.hitcircle.color
		circle.hitcircleoverlay.color = circle.hitcircle.color
	}

	// Draw
	for mut sprite in circle.sprites {
		sprite.draw(arg)
	}

	// Combo
	circle.combotext.draw(arg)
}

pub fn (mut circle Circle) update(update_time f64) bool {
	circle.last_time = update_time

	for mut sprite in circle.sprites {
		sprite.update(update_time)
	}
	circle.combotext.update(update_time)

	return false
}

pub fn (mut circle Circle) post_update(update_time f64) {
	// Free unused stuff, if possible.
	for mut c_sprite in circle.sprites {
		match c_sprite {
			sprite.Sprite {
				mut c_sprite_actual := c_sprite as sprite.Sprite

				unsafe {
					c_sprite_actual.free()
				}
			}
			else {}
		}
	}
}

pub fn (mut circle Circle) set_timing(t timing.Timings) {
	circle.timing = t
}

pub fn (mut circle Circle) set_difficulty(diff difficulty.Difficulty) {
	circle.diff = diff

	//
	start_time := circle.time.start - diff.preempt
	end_time := circle.time.start

	// init combo sprite
	circle.combotext = sprite.make_number_sprite(circle.combo_number, 'default')

	//
	if circle.inherited {
		circle.hitcircle.textures << skin.get_texture_with_fallback('sliderstartcircleoverlay',
			'hitcircleoverlay')
		circle.hitcircleoverlay.textures << skin.get_texture_with_fallback('sliderstartcircle',
			'hitcircle')
	} else {
		circle.hitcircle.textures << skin.get_texture('hitcircle')
		circle.hitcircleoverlay.textures << skin.get_texture('hitcircleoverlay')
	}

	circle.approachcircle.textures << skin.get_texture('approachcircle')

	circle.sprites << circle.hitcircle
	circle.sprites << circle.hitcircleoverlay
	circle.sprites << circle.approachcircle

	//
	mut circles := []sprite.ISprite{}
	circles << circle.hitcircle
	circles << circle.hitcircleoverlay
	circles << circle.combotext

	// Color
	circle.hitcircle.add_transform(
		typ: .color
		time: time.Time{start_time, start_time}
		before: circle.color
	)
	circle.approachcircle.add_transform(
		typ: .color
		time: time.Time{start_time, start_time}
		before: circle.color
	)

	// HACK: bruh
	if circle.inherited {
		circle.hitcircleoverlay.add_transform(
			typ: .color
			time: time.Time{start_time, start_time}
			before: circle.color
		)
	}

	for mut s in circles {
		s.add_transform(
			typ: .move
			time: time.Time{start_time, start_time}
			before: [
				circle.position.x,
				circle.position.y,
			]
		)

		if object.is_hidden {
			s.add_transform(
				typ: .fade
				time: time.Time{start_time, start_time + diff.preempt * 0.4}
				before: [0.0]
				after: [255.0]
			)
			s.add_transform(
				typ: .fade
				time: time.Time{start_time + diff.preempt * 0.4, start_time + diff.preempt * 0.7}
				before: [255.0]
				after: [0.0]
			)
		} else {
			s.add_transform(
				typ: .fade
				time: time.Time{start_time, start_time + diff.fade_in}
				before: [
					0.0,
				]
				after: [255.0]
			)
			s.add_transform(
				typ: .fade
				time: time.Time{end_time, end_time + diff.hit50}
				before: [
					255.0,
				]
			)
		}

		// Done
		s.reset_size_based_on_texture(factor: (circle.diff.circle_radius * 1.05 * 2) / 128)
		s.reset_attributes_based_on_transforms()
	}

	// Approach circle
	if !object.is_hidden || circle.id == 0 {
		circle.approachcircle.add_transform(
			typ: .move
			time: time.Time{start_time, start_time}
			before: [
				circle.position.x,
				circle.position.y,
			]
		)
		circle.approachcircle.add_transform(
			typ: .fade
			time: time.Time{start_time, math.min(end_time, end_time - diff.preempt +
				diff.fade_in * 2.0)}
			before: [0.0]
			after: [
				229.5,
			]
		) // 0.9
		circle.approachcircle.add_transform(
			typ: .fade
			time: time.Time{end_time, end_time}
			before: [
				0.0,
			]
			after: [0.0]
		)
		circle.approachcircle.add_transform(
			typ: .scale_factor
			time: time.Time{start_time, end_time}
			before: [4.0]
			after: [1.0]
		)
		circle.approachcircle.reset_size_based_on_texture(
			factor: (circle.diff.circle_radius * 1.05 * 2) / 128
		)
		circle.approachcircle.reset_attributes_based_on_transforms()
	}
}

pub fn (mut circle Circle) arm(clicked bool, _time f64) {
	circle.approachcircle.reset_transform()
	circle.combotext.reset_transform()
	circle.hitcircleoverlay.reset_transform()
	circle.hitcircle.reset_transform()

	start_time := _time
	end_scale := 1.4

	// sayonara approach circle-kun >w<
	circle.approachcircle.add_transform(
		typ: .fade
		time: time.Time{start_time, start_time}
		before: [
			0.0,
		]
	)

	if clicked && !object.is_hidden {
		end_time := start_time + difficulty.hit_fade_out

		// scale
		circle.hitcircle.add_transform(
			typ: .scale_factor
			easing: easing.quad_out
			time: time.Time{start_time, end_time}
			before: [1.0]
			after: [end_scale]
		)
		circle.hitcircleoverlay.add_transform(
			typ: .scale_factor
			easing: easing.quad_out
			time: time.Time{start_time, end_time}
			before: [1.0]
			after: [end_scale]
		)

		// fade
		circle.hitcircle.add_transform(
			typ: .fade
			time: time.Time{start_time, end_time}
			before: [
				255.0,
			]
			after: [0.0]
		)
		circle.hitcircleoverlay.add_transform(
			typ: .fade
			time: time.Time{start_time, end_time}
			before: [
				255.0,
			]
			after: [0.0]
		)
		circle.combotext.add_transform(
			typ: .fade
			time: time.Time{start_time, start_time + 60}
			before: [
				255.0,
			]
			after: [0.0]
		)
	} else {
		// Hidden or missed, same shit
		end_time := start_time + 60.0
		circle.hitcircle.add_transform(
			typ: .fade
			easing: easing.quad_out
			time: time.Time{start_time, end_time}
			before: [f64(circle.hitcircle.color.a)]
			after: [0.0]
		)
		circle.hitcircleoverlay.add_transform(
			typ: .fade
			easing: easing.quad_out
			time: time.Time{start_time, end_time}
			before: [f64(circle.hitcircleoverlay.color.a)]
			after: [0.0]
		)
		circle.combotext.add_transform(
			typ: .fade
			easing: easing.quad_out
			time: time.Time{start_time, end_time}
			before: [f64(circle.combotext.color.a)]
			after: [0.0]
		)
	}

	//  resets
	circle.hitcircle.reset_time_based_on_transforms()
	circle.hitcircleoverlay.reset_time_based_on_transforms()
	circle.approachcircle.reset_time_based_on_transforms()
	circle.combotext.reset_time_based_on_transforms()
}

pub fn (mut circle Circle) shake(_time f64) {
	for mut sprite in circle.sprites {
		sprite.remove_transform_by_type(.move_x)
		sprite.add_transform(
			typ: .move_x
			time: time.Time{_time, _time + 20}
			before: [
				circle.position.x + 0,
			]
			after: [circle.position.x + 8]
		)
		sprite.add_transform(
			typ: .move_x
			time: time.Time{_time + 20, _time + 40}
			before: [
				circle.position.x + 8,
			]
			after: [circle.position.x - 8]
		)
		sprite.add_transform(
			typ: .move_x
			time: time.Time{_time + 40, _time + 60}
			before: [
				circle.position.x - 8,
			]
			after: [circle.position.x + 8]
		)
		sprite.add_transform(
			typ: .move_x
			time: time.Time{_time + 60, _time + 80}
			before: [
				circle.position.x + 8,
			]
			after: [circle.position.x - 8]
		)
		sprite.add_transform(
			typ: .move_x
			time: time.Time{_time + 80, _time + 100}
			before: [
				circle.position.x - 8,
			]
			after: [circle.position.x + 8]
		)
		sprite.add_transform(
			typ: .move_x
			time: time.Time{_time + 100, _time + 120}
			before: [
				circle.position.x + 8,
			]
			after: [circle.position.x + 0]
		)
	}
}

pub fn (mut circle Circle) play_hitsound() {
	// play hitsound
	point := circle.timing.get_point_at(circle.time.start)

	mut index := circle.hitsound.custom_index
	mut sample_set := circle.hitsound.sample_set

	if index == 0 {
		index = point.sample_index
	}

	if sample_set == 0 {
		sample_set = point.sample_set
	}

	audio.play_sample(sample_set, circle.hitsound.addition_set, circle.sample, index,
		point.sample_volume)
}

pub fn make_circle(items []string) &Circle {
	mut hcircle := &Circle{
		HitObject: common_parse(items, 5)
	}
	hcircle.sample = items[4].int()

	return hcircle
}
