module gui

import os
import gg
import math
import library.tinyfiledialogs
import core.common.settings
import core.osu.parsers.beatmap
import core.osu.runtime.gameplay
import framework.logging
import framework.audio
import framework.graphic.context
import framework.graphic.window as i_window
import framework.math.time

// Const
const c_scene_error = 0xFAC
const c_scene_none = int(0 << 0)
const c_scene_main = int(1 << 0)
const c_scene_pre_gameplay = int(1 << 1)
const c_scene_loading_gameplay = int(1 << 2)
const c_scene_gameplay = int(1 << 3)

// Structs
@[heap]
pub struct GUIWindow {
	i_window.GeneralWindow
mut:
	time &time.TimeCounter = unsafe { nil }
pub mut:
	manager  &beatmap.BeatmapManager = unsafe { nil }
	menu     &MainMenu = unsafe { nil }
	gameplay &gameplay.OSUGameplay = unsafe { nil }
	// TODO: Rename this god awful fields lmao
	joe   bool   // Has song loaded yet
	joe_i int    // Index of beatmap
	joe_s int    // Current Scene
	joe_p string // Path of the beatmap (Temp)
	joe_c int    // Useless counter for uselss thing
	joe_t gameplay.OSUGameplayMode // Which mode to open gameplay with
	joe_r string // Replay Path
}

pub fn (mut window GUIWindow) init(_ voidptr) {
	window.joe_s = gui.c_scene_main

	// Reset time
	window.time = time.get_time()

	// Start
	logging.info('Initialize.')

	window.manager = beatmap.make_manager(settings.global.gameplay.paths.beatmaps)

	logging.info('Found beatmaps: ${window.manager.beatmaps.len} beatmaps')

	// Scenes
	logging.info('Setting up scenes.')

	window.menu = &MainMenu{
		window: window
		current_track: audio.new_dummy_track()
	}

	logging.info('Done setting up scenes.')

	//
	window.start_update_thread()

	// Test
	if window.manager.beatmaps.len > 0 {
		window.menu.change_beatmap(&window.manager.beatmaps[0])
	} else {
		window.joe_s = gui.c_scene_error
		logging.error('No beatmap found on: ${settings.global.gameplay.paths.beatmaps}')
	}
}

pub fn (mut window GUIWindow) draw(_ voidptr) {
	window.tick_draw()

	// Draw scenes
	match window.joe_s {
		gui.c_scene_error {
			window.ctx.begin()

			window.ctx.draw_text(int(settings.global.window.width / 2), int(settings.global.window.height / 2),
				'Invalid beatmap path!',
				color: gg.Color{255, 255, 255, 255}
				size: 32
				align: .center
				vertical_align: .middle
			)

			window.GeneralWindow.draw_branding()
			window.draw_stats()

			// Draw the last 32 logs
			mut t := 1
			for i := logging.global.logs.len - 1; i > math.max(logging.global.logs.len - 32,
				0); i-- {
				t++
				window.ctx.draw_rect_filled(0, int(settings.global.window.height) - t * 16,
					window.ctx.text_width(logging.global.logs[i]), 16, gg.Color{0, 0, 0, 100})
				window.ctx.draw_text(0, int(settings.global.window.height) - t * 16, logging.global.logs[i],
					color: gg.Color{255, 255, 255, 100}
				)
			}

			window.ctx.end()
		}
		gui.c_scene_main {
			window.ctx.begin()
			window.mutex.@lock()
			window.menu.draw(ctx: window.ctx)
			window.mutex.unlock()

			window.GeneralWindow.draw_branding()
			window.draw_stats()

			// Draw the last 32 logs
			mut t := 1
			for i := logging.global.logs.len - 1; i > math.max(logging.global.logs.len - 32,
				0); i-- {
				t++
				window.ctx.draw_rect_filled(0, int(settings.global.window.height) - t * 16,
					window.ctx.text_width(logging.global.logs[i]), 16, gg.Color{0, 0, 0, 100})
				window.ctx.draw_text(0, int(settings.global.window.height) - t * 16, logging.global.logs[i],
					color: gg.Color{255, 255, 255, 100}
				)
			}

			window.ctx.end()
		}
		gui.c_scene_pre_gameplay {
			// Black screen with loading
			window.ctx.begin()

			window.mutex.@lock()
			window.menu.draw(ctx: window.ctx)
			window.mutex.unlock()

			window.ctx.draw_rect_filled(0, 0, int(settings.global.window.width), int(settings.global.window.height),
				gg.Color{0, 0, 0, 200})

			window.ctx.draw_text(int(settings.global.window.width) / 2, int(settings.global.window.height) / 2,
				'Loading...',
				color: gg.Color{255, 255, 255, 255}
				size: 64
				align: .center
				vertical_align: .middle
			)

			window.ctx.end()

			// 10 frames to sokol can draw stuff properly
			window.joe_c++

			if window.joe_c > 10 {
				window.joe_s = gui.c_scene_loading_gameplay
			}
		}
		gui.c_scene_loading_gameplay {
			// This is kinda hacky but whatever.
			// Load gameplay.
			logging.info('Loading gameplay.')

			window.gameplay = &gameplay.OSUGameplay{
				cursor: &voidptr(0) // NOTE: Not safe.
				beatmap_audio: audio.new_dummy_track()
			}

			window.gameplay.init(mut window.ctx, window.menu.current_version, window.joe_t,
				window.joe_r)

			window.time.reset()
			context.vsync(false)

			logging.info('Gameplay loaded?')

			window.joe_s = gui.c_scene_gameplay
		}
		gui.c_scene_gameplay {
			window.mutex.@lock()
			window.gameplay.draw(mut window.ctx)
			window.mutex.unlock()

			window.ctx.begin()
			window.GeneralWindow.draw_branding()
			window.draw_stats()

			// Draw the last 16 logs
			mut t := 1
			for i := logging.global.logs.len - 1; i > math.max(logging.global.logs.len - 16,
				0); i-- {
				t++
				window.ctx.draw_rect_filled(0, t * 16, window.ctx.text_width(logging.global.logs[i]),
					16, gg.Color{0, 0, 0, 200})
				window.ctx.draw_text(0, t * 16, logging.global.logs[i],
					color: gg.Color{255, 255, 255, 100}
				)
			}
			window.ctx.end_short()
		}
		else {}
	}
}

// Updates
pub fn (mut window GUIWindow) start_update_thread() {
	logging.info('Update thread starting.')

	go fn (mut window GUIWindow) {
		logging.info('Update thread started.')

		window.time.reset()

		mut limiter := time.Limiter{1000, 0, 0}

		for {
			window.mutex.@lock()
			window.update(window.time.time)
			window.mutex.unlock()
			limiter.sync()
		}
	}(mut window)
}

pub fn (mut window GUIWindow) update(time_ms f64) {
	window.tick_update()

	match window.joe_s {
		gui.c_scene_main {
			window.menu.update(time_ms)
		}
		gui.c_scene_gameplay {
			window.gameplay.update(time_ms, window.time.delta)
		}
		else {}
	}
}

// Enter
pub fn (mut window GUIWindow) play_beatmap(path string, typ gameplay.OSUGameplayMode) {
	window.joe_s = gui.c_scene_pre_gameplay // Getting reading to load
	window.joe_p = path
	window.joe_t = typ

	logging.info('Getting ready to start gameplay.')

	window.menu.current_track.pause()
	window.menu.background.fadeout_and_die(window.time.time, 200.0)

	logging.info('Killed background.')
}

// Events
pub fn (mut window GUIWindow) event_keydown(key gg.KeyCode, mod gg.Modifier, _ voidptr) {
	for dont_handle_on_this_scene in [gui.c_scene_pre_gameplay, gui.c_scene_loading_gameplay,
		gui.c_scene_error] {
		if window.joe_s == dont_handle_on_this_scene {
			return
		}
	}

	if window.joe_s == gui.c_scene_gameplay {
		window.gameplay.event_keydown(key)
		return
	}

	match key {
		.right {
			window.joe_i++

			window.menu.change_beatmap(&window.manager.beatmaps[window.joe_i % window.manager.beatmaps.len])
		}
		.left {
			window.joe_i--

			if window.joe_i < 0 {
				window.joe_i = window.manager.beatmaps.len - 1
			}

			window.menu.change_beatmap(&window.manager.beatmaps[window.joe_i % window.manager.beatmaps.len])
		}
		.up {
			window.menu.prev_version()
		}
		.down {
			window.menu.next_version()
		}
		.p {
			logging.info('Play beatmap.')
			window.play_beatmap(os.join_path(window.menu.current_version.root, window.menu.current_version.filename),
				.player)
		}
		.a {
			logging.info('Picked auto.')
			window.play_beatmap(os.join_path(window.menu.current_version.root, window.menu.current_version.filename),
				.auto)
		}
		.r {
			logging.info('Picking replay.')

			replay_path := tinyfiledialogs.open_file_picker('Pick a replay file!', '',
				['*.osr'], 'osu! replay', false)

			if replay_path.len == 0 || !os.exists(replay_path) {
				logging.error('Invalid replay file.')
				return
			}

			logging.info('Replay picked: ${replay_path}')

			window.joe_r = replay_path
			window.play_beatmap(os.join_path(window.menu.current_version.root, window.menu.current_version.filename),
				.replay)
		}
		else {
			logging.debug('Unhandled key: ${key}')
		}
	}
}

pub fn (mut window GUIWindow) event_keyup(key gg.KeyCode, mod gg.Modifier, _ voidptr) {
	for dont_handle_on_this_scene in [gui.c_scene_pre_gameplay, gui.c_scene_loading_gameplay,
		gui.c_scene_error] {
		if window.joe_s == dont_handle_on_this_scene {
			return
		}
	}

	match window.joe_s {
		gui.c_scene_gameplay {
			window.gameplay.event_keyup(key)
		}
		else {}
	}
}

pub fn (mut window GUIWindow) event_mouse(x f32, y f32, _ voidptr) {
	if window.joe_s != gui.c_scene_gameplay {
		return
	}

	window.gameplay.event_mouse(x, y)
}

pub fn run(args []string) {
	mut window := &GUIWindow{
		manager: unsafe { 0 }
	}

	logging.info('Runtime logs:')
	logging.info('Hello world.')

	logging.info('Creating GG context.')

	mut gg_context := gg.new_context(
		// Basic
		width: int(settings.global.window.width)
		height: int(settings.global.window.height)
		user_data: window
		// FNs
		init_fn: window.init
		frame_fn: window.draw
		// Event
		keydown_fn: window.event_keydown
		keyup_fn: window.event_keyup
		move_fn: window.event_mouse
	)

	window.ctx = context.Context.create(mut gg_context)

	logging.info('Wrapping Context with our own impl.')
	logging.info('Get ready to run.')

	window.ctx.run()
}
