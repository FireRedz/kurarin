module runtime

import core.common.settings // Load this first
import gx
import math
import sokol.gfx
import sokol.sgl
import sokol.sapp
import time as timelib
import gg
import core.osu.parsers.beatmap.object.graphic
import framework.logging

pub fn (mut window Window) draw_normal(_ voidptr) {
	window.mutex.@lock()
	window.render()
	window.mutex.unlock()

	window.GeneralWindow.tick_draw()
	window.limiter.sync()
}

pub fn (mut window Window) render() {
	window.beatmap.free_slider_attr()

	// Background
	window.ctx.begin()
	window.ctx.end()

	// Game
	window.beatmap.draw()

	if settings.global.gameplay.overlay.visualizer {
		window.visualizer.draw(mut window.ctx)
	}

	if settings.global.gameplay.overlay.info {
		window.overlay.draw()
	}

	// TODO: maybe move cursor to beatmap struct
	if settings.global.gameplay.skin.cursor.visible {
		for mut cursor in window.cursors {
			cursor.draw()
		}
	}

	window.ctx.begin()

	// Texts (only on windowed mode)
	if !settings.global.video.record {
		window.GeneralWindow.draw_branding()
		window.GeneralWindow.draw_stats()
	}

	gfx.begin_pass(sapp.create_default_pass(graphic.global_renderer.pass_action))
	sgl.draw()
	gfx.end_pass()

	gfx.commit()
}

pub fn (mut window Window) draw_record(_ voidptr) {
	window_size := gg.window_size()

	if window_size.width != int(settings.global.window.width)
		|| window_size.height != int(settings.global.window.height) {
		window.ctx.begin()
		window.ctx.resize(int(settings.global.window.width), int(settings.global.window.height))
		window.ctx.draw_text(0, 0, 'Please make sure the window resolution is [${int(settings.global.window.width)}, ${int(settings.global.window.height)}].',
			gx.TextCfg{ color: gx.white })
		window.ctx.end()
		return
	}

	logging.info('Video rendering started!')

	// Render
	fps := settings.global.video.fps
	update_fps := 1000.0
	update_delta := 1000.0 / update_fps
	fps_delta := 1000.0 / fps
	audio_fps := settings.global.video.update_fps
	audio_delta := 1000.0 / audio_fps

	mut delta_sum_frame := fps_delta
	mut delta_sum_audio := 0.0

	end_time := (window.beatmap.time.end + 7000.0) * settings.global.window.speed
	mut current_time := 0.0

	// Stats
	mut last_progress := int(0)
	mut last_count := i64(0)
	mut count := i64(0)
	mut last_time := timelib.ticks()

	for current_time <= end_time {
		window.update(current_time, update_delta)

		delta_sum_audio += update_delta

		for delta_sum_audio >= audio_delta {
			window.video.pipe_audio()

			delta_sum_audio -= audio_delta
		}

		delta_sum_frame += update_delta

		if delta_sum_frame >= fps_delta {
			window.render()
			window.video.pipe_window()

			// Print progress
			count++
			progress := int((current_time / end_time) * 100.0)

			if math.fmod(progress, 5) == 0 && progress != last_progress {
				speed := f64(count - last_count) * (1000 / settings.global.video.fps) / (timelib.ticks() - last_time)
				eta := int((end_time - current_time) / 1000.0 / speed)

				mut eta_text := ''

				hours := (eta / 3600) % 24
				minutes := (eta / 60) % 60

				if hours > 0 {
					eta_text += '${hours}h '
				}

				if minutes > 0 {
					eta_text += '${minutes % 60:02}m '
				}

				eta_text += '${eta % 60}s'

				logging.info('Progress: ${progress}% | Speed: ${speed:.2f}x | ETA: ${eta_text}')

				last_time = timelib.ticks()
				last_count = count
				last_progress = progress
			}
			delta_sum_frame -= fps_delta
		}

		current_time += update_delta * settings.global.window.speed
	}

	window.ctx.quit() // Ok we're done...
}
