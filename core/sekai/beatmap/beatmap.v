module beatmap

import gx
import library.gg
import sokol.sgl

import math

// import framework.logging
import framework.graphic.sprite

import framework.math.time
import framework.math.vector

import object
import timing

// god i fucking hate typescript/javascript
// source: https://github.com/NonSpicyBurrito/sonolus-pjsekai-engine/blob/d2a3c6bda1ef43502e77dcc39cb6e965f86cec7e/src/lib/sus/analyze.ts#L3

pub const (
		ticks_per_beat = 480.0
		ticks_per_hidden = ticks_per_beat / 2.0
)

// Structs
pub struct Line {
	pub mut:
		header string
		data string
}

pub struct MeasureChange {
	pub mut:
		a f64
		b f64
}

pub struct RawObject {
	pub mut:
		tick f64
		value string
}
//

pub struct Beatmap {
	mut:
		ctx &gg.Context = voidptr(0)

	pub mut:
		lines   []Line
		measure []MeasureChange
		meta    map[string]string
		
		bpms map[string]f64
		bpm_changes []&RawObject
		tap_notes []&object.NoteObject
		directional_notes []&object.NoteObject
		stream map[string]&object.NoteObject

		// Queue
		queue []&object.NoteObject
		finished []&object.NoteObject

		bars timing.Bars
		timings timing.Timing

		objects_i int

		// Internal
		flicks map[string]int
		
		// Visuals
		background &sprite.Manager = sprite.make_manager()
}

pub fn (mut beatmap Beatmap) bind_context(mut ctx &gg.Context) {
	beatmap.ctx = unsafe { ctx }
}

// FNs
pub fn (mut beatmap Beatmap) update(time f64) {
	preempt := 700.0

	// Update queue
	for i := beatmap.objects_i; i < beatmap.tap_notes.len; i++ {
		if (time >= beatmap.tap_notes[i].time.start - preempt) &&
			(time <= beatmap.tap_notes[i].time.end) {
				// logging.info("${@MOD}: Added to queue")
				beatmap.queue << beatmap.tap_notes[i]
				beatmap.objects_i++
				continue
			}
	}

	// Update queue objects
	for i := 0; i < beatmap.queue.len; i++ {
		// Remove if ended
		if time >= (beatmap.queue[i].time.end + 500.0) {
			// logging.info("${@MOD}: Removed from queue")
			beatmap.finished << beatmap.queue[i]

			beatmap.queue = beatmap.queue[1 .. ]
			i--
			continue
		}
		
		// Update
		beatmap.queue[i].update(time)
	}

}

pub fn (mut beatmap Beatmap) draw(arg sprite.CommonSpriteArgument) {
	arg.ctx.draw_rect_filled(0, 0, 1280, 720, gx.gray)
	beatmap.background.draw(arg)

	// Perspective
	sgl.defaults()
	sgl.load_pipeline(arg.ctx.timage_pip)

	fov := f32(50.0)

	sgl.matrix_mode_projection()
	sgl.perspective(sgl.rad(fov), 1.0, 0.0, 1000.0)

	sgl.matrix_mode_modelview()
	sgl.translate(0.0, 0.0, -13.0)

	sgl.rotate(sgl.rad(-60), 1.0, 0.0, 0.0)
	sgl.rotate(sgl.rad(0), 0.0, 1.0, 0.0)

	arg.ctx.draw_rect_filled(-0.5 * 6.5, -7.3, 0.5 * 13, 1, gx.red)
	arg.ctx.draw_line(0, 0, 0, 100, gx.green)

	for mut note in beatmap.queue {
		if arg.time >= note.time.start {
			note.draw(arg)
		}
	}

	// Reset camera
	sgl.defaults()
	sgl.matrix_mode_projection()
	sgl.ortho(0.0, 1280, 720, 0.0, -1.0, 1.0)
}

// Ensures
pub fn (mut beatmap Beatmap) ensure_background_loaded() {
	// Background
	for i, filename in ["default", "field"] {
		mut sprite := &sprite.Sprite{always_visible: true}
		sprite.textures << beatmap.ctx.create_image("assets/psekai/textures/${filename}.png")


		sprite.add_transform(typ: .move, time: time.Time{0.0, 0.0}, before: [1280.0 / 2.0, 720.0 / 2.0 + (f64(i) * 70.0)])

		if i == 1 {
			sprite.add_transform(typ: .scale_factor, time: time.Time{0.0, 0.0}, before: [1.18])
		}

		sprite.reset_size_based_on_texture(fit_size: true, source: vector.Vector2{1280, 720})		
		sprite.reset_attributes_based_on_transforms()

		beatmap.background.add(mut sprite)
	}

	// References
	// mut sprite := &sprite.Sprite{always_visible: true}
	// sprite.textures << beatmap.ctx.create_image("assets/psekai/textures/ref2.jpeg")
	// sprite.color.a = 0

	// sprite.add_transform(typ: .move, time: time.Time{0.0, 0.0}, before: [1280.0 / 2.0, 720.0 / 2.0])

	// sprite.reset_size_based_on_texture()
	// sprite.reset_attributes_based_on_transforms()
	// beatmap.background.add(mut sprite)
}

// Resolver
pub fn (mut beatmap Beatmap) resolve_object_time() {
	for mut note in beatmap.tap_notes {
		time := beatmap.to_time(note.tick)
		note.time.start = time
		note.time.end = time
	}
}

pub fn (mut beatmap Beatmap) reset() {
	// Load bgs
	beatmap.ensure_background_loaded()

	// Init note objects
	for i := 0; i < beatmap.tap_notes.len; i++ {
		key := get_key(beatmap.tap_notes[i].BaseNoteObject)

		
		is_flick := key in beatmap.flicks
		is_critical := beatmap.tap_notes[i].typ == 2

		beatmap.tap_notes[i].initialize(is_flick, is_critical)
	}
}

// Time converters
pub fn (mut beatmap Beatmap) to_tick(measure f64, p f64, q f64) f64 {
	return beatmap.bars.to_tick(measure, p, q)
}

pub fn (mut beatmap Beatmap) to_time(tick f64) f64 {
	return beatmap.timings.to_time(tick)
}