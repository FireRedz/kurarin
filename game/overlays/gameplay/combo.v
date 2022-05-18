module gameplay

import math

import framework.audio as f_audio
import game.audio as g_audio

import framework.math.time
import framework.math.easing
import framework.math.glider
import framework.math.vector
import framework.graphic.sprite

pub struct ComboCounter {
	pub mut:
		combo int
		combo_display int
		main_font &sprite.NumberSprite = voidptr(0)
		pop_font &sprite.NumberSprite = voidptr(0)

		combo_break f_audio.Sample

		main_glider &glider.Glider = glider.new_glider(1.0)
		pop_glider &glider.Glider = glider.new_glider(1.0)
		last_time f64
}

pub fn (mut counter ComboCounter) increase() {
	counter.combo++

	counter.main_glider.add_event_start(counter.last_time, counter.last_time + 150.0, 1.0, 1.1)
	counter.main_glider.add_event_start(counter.last_time + 150.0, counter.last_time + 200.0, 1.1, 1.0)

	counter.pop_glider.add_event_start(counter.last_time, counter.last_time + 150.0, 1.0, 1.5)
	counter.pop_glider.add_event_start(counter.last_time + 150.0, counter.last_time + 250.0, 1.5, 1.0)
}

pub fn (mut counter ComboCounter) reset() {
	if counter.combo > 20 {
		counter.combo_break.play()
	}

	counter.combo = 0
}

pub fn (mut counter ComboCounter) update(time f64) {
	counter.main_glider.update(time)
	counter.pop_glider.update(time)

	counter.last_time = time
}

pub fn (mut counter ComboCounter) draw(arg sprite.CommonSpriteArgument) {
	main_scale := math.max<f64>(counter.main_glider.value, 1.0)
	pop_scale := math.max<f64>(counter.pop_glider.value, 1.0)
	counter.main_font.draw_number(counter.combo.str(), vector.Vector2{5, 715 - counter.main_font.size.y * main_scale}, vector.top_left, sprite.CommonSpriteArgument{...arg, scale: main_scale})
	counter.pop_font.draw_number(counter.combo.str(), vector.Vector2{5, 715 - counter.pop_font.size.y * pop_scale}, vector.top_left, sprite.CommonSpriteArgument{...arg, scale: pop_scale})
}

pub fn make_combo_counter() &ComboCounter {
	mut counter := &ComboCounter{
		combo_break: g_audio.get_sample("combobreak"),
		main_font: sprite.make_number_font("combo"),
		pop_font: sprite.make_number_font("combo")
	}
	
	counter.main_glider.easing = easing.quad_out
	counter.pop_glider.easing = easing.quad_out

	// PopFont alpha
	counter.pop_font.add_transform(typ: .fade, time: time.Time{0.0, 0.0}, before: [100.0])
	counter.pop_font.reset_attributes_based_on_transforms()

	return counter
}