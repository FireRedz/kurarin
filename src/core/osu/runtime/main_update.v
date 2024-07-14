module runtime

import core.common.settings // Load this first
import math
import sokol.sapp
import framework.math.time

pub fn (mut window Window) update_thread() {
	mut g_time := time.get_time()
	mut limiter := time.Limiter{1000, 0, 0}
	g_time.reset()
	g_time.set_speed(settings.global.window.speed)

	// Disable mouse
	sapp.show_mouse(false)

	for {
		window.mutex.@lock()
		window.update(g_time.time, g_time.delta)
		window.mutex.unlock()

		window.GeneralWindow.tick_update()
		limiter.sync()
	}
}

pub fn (mut window Window) update(update_time f64, delta f64) {
	if update_time >= settings.global.gameplay.playfield.lead_in_time && !window.audio_been_played {
		window.audio_been_played = true
		window.beatmap_song.set_speed(settings.global.window.speed)
		window.beatmap_song.set_pitch(settings.global.audio.pitch)
		window.beatmap_song.set_volume(f32(settings.global.audio.music * settings.global.audio.global / 10000))
		window.beatmap_song.set_position(update_time - settings.global.gameplay.playfield.lead_in_time) // HACK: Catch up with the game_time, sometime its too fast.
		window.beatmap_song.play()
	}

	// Ruleset
	window.ruleset_mutex.@lock()
	window.ruleset.update_click_for(window.cursors[0], update_time - settings.global.gameplay.playfield.lead_in_time)
	window.ruleset.update_normal_for(window.cursors[0], update_time - settings.global.gameplay.playfield.lead_in_time,
		false)
	window.ruleset.update_post_for(window.cursors[0], update_time - settings.global.gameplay.playfield.lead_in_time,
		false)
	window.ruleset.update(update_time - settings.global.gameplay.playfield.lead_in_time)
	window.ruleset_mutex.unlock()

	window.beatmap.update(update_time - settings.global.gameplay.playfield.lead_in_time,
		window.beatmap_song_boost)

	// Overlay
	if settings.global.gameplay.overlay.info {
		window.overlay.update(update_time - settings.global.gameplay.playfield.lead_in_time)
	}

	if settings.global.gameplay.overlay.visualizer {
		window.visualizer.update(update_time - settings.global.gameplay.playfield.lead_in_time)
	}

	window.beatmap_song.update(update_time - settings.global.gameplay.playfield.lead_in_time)
	window.update_cursor(update_time - settings.global.gameplay.playfield.lead_in_time,
		delta)
	window.update_boost()
}

pub fn (mut window Window) update_boost() {
	if settings.global.gameplay.hitobjects.scale_to_beat {
		// target := math.clamp(1.0 + (0.5 * window.beatmap_song.effects.peak_raw), 1.0,
		// 	2.0) // 2.0 is the max
		// window.beatmap_song_boost = f32(target * 0.1 + window.beatmap_song_boost - window.beatmap_song_boost * 0.1)

		// rate := 0.15 * (time.global.delta / 8.33334) // 120fps
		// window.beatmap_song_boost = f32(target * rate + window.beatmap_song_boost - window.beatmap_song_boost * rate)
	}
}

pub fn (mut window Window) update_cursor(update_time f64, delta f64) {
	if window.argument.play_mode != .play {
		window.cursor_controller.update(update_time, delta)
	}

	for mut cursor in window.cursors {
		cursor.update(update_time, delta)
	}

	// Rainbow mode if theres only one cursor
	if window.cursors.len == 1 {
		color_index := (f32(math.fmod(update_time / 100.0, 10000)) / 10000.0) + 0.1
		window.cursors[0].trail_color.r = u8(f32(math.sin(0.3 * (update_time / 1000.0) + 0 +
			1 * color_index) * 127.0 + 128.0))
		window.cursors[0].trail_color.g = u8(f32(math.sin(0.3 * (update_time / 1000.0) + 2 +
			1 * color_index) * 127.0 + 128.0))
		window.cursors[0].trail_color.b = u8(f32(math.sin(0.3 * (update_time / 1000.0) + 4 +
			1 * color_index) * 127.0 + 128.0))
	}
}
