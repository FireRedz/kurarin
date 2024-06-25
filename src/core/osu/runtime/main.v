module runtime

import core.common.settings // Load this first
import os
import gx
import math
import sync
import sokol.gfx
import sokol.sgl
import sokol.sapp
import time as timelib
import gg
import core.osu.x
import core.osu.system.skin
import core.osu.system.player
import core.osu.gameplay.cursor
import core.osu.parsers.beatmap
import core.osu.gameplay.ruleset
import core.osu.gameplay.overlays
import core.osu.parsers.beatmap.object.graphic
import framework.audio
import framework.audio.common
import framework.logging
import framework.math.time
import framework.math.vector
import framework.graphic.visualizer
import framework.graphic.window as i_window
import framework.graphic.context
import framework.ffmpeg.export

pub struct Window {
	i_window.GeneralWindow
mut:
	play_mode PlayState
pub mut:
	beatmap           &beatmap.Beatmap = unsafe { nil }
	cursors           []&cursor.Cursor
	cursor_controller cursor.ICursorController // Used for auto and replay
	argument          &GameArgument = unsafe { nil }
	// TODO: move this to somewhere else
	audio_been_played bool
	limiter           &time.Limiter = &time.Limiter{int(settings.global.window.fps), 0, 0}
	// Ruleset
	ruleset       &ruleset.Ruleset = unsafe { nil }
	ruleset_mutex &sync.Mutex      = sync.new_mutex()
	// Overlay
	visualizer &visualizer.Visualizer    = unsafe { nil }
	overlay    &overlays.GameplayOverlay = unsafe { nil }
	// Recording stuff
	record bool
	video  &export.Video = unsafe { nil }
	// HACK: move this to somewhere else
	beatmap_song       &common.ITrack
	beatmap_song_boost f32 = f32(1.0)
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

pub fn (mut window Window) draw() {
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
		window.GeneralWindow.draw_stats()
	}

	gfx.begin_pass(sapp.create_default_pass(graphic.global_renderer.pass_action))
	sgl.draw()
	gfx.end_pass()

	gfx.commit()
}

pub fn window_init(mut window Window) {
	// Init Renderer(s)

	// Renderer: Slider
	graphic.init_slider_renderer()

	// Renderer: Turn off VSync [HACK]
	context.vsync(false)

	// NOTE: Routine starts here
	mut loaded_beatmap := beatmap.parse_beatmap(window.argument.beatmap_path, false)

	window.beatmap = loaded_beatmap
	window.beatmap.bind_context(mut window.ctx)
	window.beatmap.reset()

	// Init beatmap bg song
	window.beatmap_song = audio.new_track(window.beatmap.get_audio_path())
	// Visualizer stuff
	if settings.global.gameplay.overlay.visualizer {
		window.visualizer = &visualizer.Visualizer{
			music: window.beatmap_song
		}

		window.visualizer.inverted = true
		window.visualizer.bars = 300
		window.visualizer.fft = []f64{len: window.visualizer.bars}
		window.visualizer.jump_size = 1
		window.visualizer.multiplier = 1.0
		window.visualizer.bar_length = 1000.0
		window.visualizer.start_distance = 0.0
		window.visualizer.update_logo(vector.Vector2[f64]{0, 0}, vector.Vector2[f64]{settings.global.window.width, settings.global.window.height})
	}

	mut current_player := player.Player{
		name: 'Player'
	}
	// Make cursor based on argument
	if window.argument.play_mode == .play {
		window.cursors << cursor.make_cursor(mut window.ctx)
	} else if window.argument.play_mode == .replay {
		// HACK: REPLAY HACK
		window.cursor_controller = cursor.make_replay_cursor(mut window.ctx, window.argument.replay_path)
		current_player = window.cursor_controller.player
		window.cursors << unsafe { window.cursor_controller.cursor }
	} else {
		window.cursor_controller = cursor.make_auto_cursor(mut window.ctx, window.beatmap.objects)
		current_player = window.cursor_controller.player
		window.cursors << unsafe { window.cursor_controller.cursor }
	}

	// Make ruleset
	window.ruleset = ruleset.new_ruleset(mut window.beatmap, mut window.cursors)

	// Overlay
	if settings.global.gameplay.overlay.info {
		window.overlay = overlays.new_gameplay_overlay(window.ruleset, window.cursors[0],
			current_player, window.ctx)
	}

	// If recording
	if window.record {
		window.video.init_video_pipe_process()
		window.video.init_audio_pipe_process()

		// Time shit
		mut g_time := time.get_time()
		g_time.set_speed(settings.global.window.speed)
		g_time.use_custom_delta = true
		g_time.custom_delta = 1000.0 / settings.global.video.fps
	}

	// Update loop
	if !window.record {
		spawn fn (mut window Window) {
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
		}(mut window)
	}
}

pub fn window_draw(mut window Window) {
	// window.ctx.load_image_queue()

	window.mutex.@lock()
	window.draw()
	window.mutex.unlock()

	window.GeneralWindow.tick_draw()
	window.limiter.sync()
}

pub fn window_draw_recording(mut window Window) {
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
			window.draw()
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

pub fn initiate_game_loop(argument GameArgument) {
	mut window := &Window{
		beatmap_song: audio.new_dummy_track()
		cursor_controller: unsafe { nil }
	}
	window.argument = &argument

	mut gg_context := gg.new_context(
		width: int(settings.global.window.width)
		height: int(settings.global.window.height)
		user_data: window
		bg_color: gx.black
		// FNs
		init_fn: window_init
		frame_fn: [window_draw, window_draw_recording][int(settings.global.video.record)] // yea...
		move_fn: fn (x_ f32, y_ f32, mut window Window) {
			// C.mu_input_mousemove(&window.microui.ctx, int(x_), int(y_))

			if window.argument.play_mode != .play {
				return
			}

			window.cursors[0].position.x = (x_ - x.resolution.offset.x) / x.resolution.playfield_scale
			window.cursors[0].position.y = (y_ - x.resolution.offset.y) / x.resolution.playfield_scale
		}
		scroll_fn: fn (ev &gg.Event, mut window Window) {
			// C.mu_input_scroll(&window.microui.ctx, -ev.scroll_x, -ev.scroll_y * 6)
		}
		click_fn: fn (pos_x f32, pos_y f32, button gg.MouseButton, mut window Window) {
			// C.mu_input_mousedown(&window.microui.ctx, int(x), int(y), int(button) + 1)
		}
		unclick_fn: fn (pos_x f32, pos_y f32, button gg.MouseButton, mut window Window) {
			// C.mu_input_mouseup(&window.microui.ctx, int(x), int(y), int(button) + 1)
		}
		keydown_fn: fn (keycode gg.KeyCode, modifier gg.Modifier, mut window Window) {
			if window.argument.play_mode != .play {
				return
			}

			window.ruleset_mutex.@lock()
			if keycode == .a {
				window.cursors[0].input.left_button = true
			}

			if keycode == .s {
				window.cursors[0].input.right_button = true
			}

			window.ruleset_mutex.unlock()
		}
		keyup_fn: fn (keycode gg.KeyCode, modifier gg.Modifier, mut window Window) {
			if window.argument.play_mode != .play {
				return
			}

			window.ruleset_mutex.@lock()
			if keycode == .a {
				window.cursors[0].input.left_button = false
			}

			if keycode == .s {
				window.cursors[0].input.right_button = false
			}

			window.ruleset_mutex.unlock()
		}
	)

	window.ctx = context.Context.create(mut gg_context)

	// Record or na
	if settings.global.video.record {
		window.record = true
		window.video = &export.Video{}
	}

	// Don't record if we're playing the game, only record for auto (and replays soon).
	if window.record && argument.play_mode == .play {
		logging.error('Recording is unavailable rn due to gameplay refactor, try again later.')
		exit(1)
	}

	skin.bind_context(mut window.ctx)

	if window.record {
		mut g_time := time.get_time()
		g_time.stop()
		g_time.reset()
	}

	window.ctx.run()

	if window.record {
		window.video.close_pipe_process()
	}
}

// Mountpoint
pub enum PlayState {
	auto
	replay
	play
}

pub struct GameArgument {
pub mut:
	beatmap_path string
	replay_path  string
	play_mode    PlayState
}

pub fn run(beatmap_path string, replay_path string, _is_playing bool) {
	mut play_mode := PlayState.auto

	// Playing checks
	if _is_playing {
		play_mode = .play
	}

	if replay_path.len > 0 {
		play_mode = .replay
	}

	// Checks
	if !os.exists(beatmap_path) {
		logging.error('Invalid beatmap path: ${beatmap_path}')
		return
	}

	if !os.exists(replay_path) && replay_path.len != 0 {
		logging.info('Invalid replay path, whatever, continuing with auto.')
		play_mode = .auto
	}

	// Create GameArgument
	argument := &GameArgument{
		beatmap_path: beatmap_path
		replay_path: replay_path
		play_mode: play_mode
	}

	logging.info('Beatmap: ${beatmap_path}')

	initiate_game_loop(argument)
}
