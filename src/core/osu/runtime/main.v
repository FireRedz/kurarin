module runtime

import core.common.settings // Load this first
import os
import gx
import sync
import gg
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
import framework.graphic.visualizer
import framework.graphic.window as i_window
import framework.graphic.context
import framework.ffmpeg.export

@[heap]
pub struct Window {
	i_window.GeneralWindow
mut:
	play_mode PlayState
pub mut:
	beatmap        &beatmap.Beatmap = unsafe { nil }
	current_player player.Player    = player.Player{
		name: 'Junko'
	}
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

pub fn (mut window Window) initialize(_ &voidptr) {
	// Renderers: Initialize
	graphic.init_slider_renderer()
	context.vsync(false)

	// Load beatmap
	window.beatmap = beatmap.parse_beatmap(window.argument.beatmap_path, false)
	window.beatmap_song = audio.new_track(window.beatmap.get_audio_path())

	window.beatmap.bind_context(mut window.ctx)
	window.beatmap.reset()

	// Visualizer
	if settings.global.gameplay.overlay.visualizer {
		logging.debug('[Visualizer] Initializing...')
		window.initialize_audio_visualizer()
		logging.debug('[Visualizer] Initialized!')
	}

	window.initialize_player()

	// Ruleset
	window.ruleset = ruleset.new_ruleset(mut window.beatmap, mut window.cursors)

	// Overlay (only for Non-TAG mode)
	if settings.global.gameplay.overlay.info && window.argument.play_mode != .tag {
		logging.debug('[Overlay] Initializing...')
		logging.debug('[Overlay] Player info: ${window.current_player.name}')
		logging.debug('[Overlay] Amount of Cursor: ${window.cursors.len}')
		window.overlay = overlays.new_gameplay_overlay(window.ruleset, window.cursors[0],
			window.current_player, window.ctx)
		logging.debug('[Overlay] Initialized! Current player is ${window.current_player.name}.')
	}

	if window.record {
		window.initialize_recording()
	} else {
		spawn window.update_thread()
	}
}

pub fn initiate_game_loop(argument GameArgument) {
	mut window := &Window{
		beatmap_song: audio.new_dummy_track()
		cursor_controller: unsafe { nil }
	}

	window.argument = &argument

	mut draw_callback := window.draw_normal

	if settings.global.video.record {
		draw_callback = window.draw_record
	}

	mut gg_context := gg.new_context(
		width: int(settings.global.window.width)
		height: int(settings.global.window.height)
		user_data: window
		bg_color: gx.black
		// Callback FNs
		init_fn: window.initialize
		frame_fn: draw_callback
		move_fn: window.mouse_move
		scroll_fn: window.mouse_scroll
		click_fn: window.mouse_click
		unclick_fn: window.mouse_unclick
		keydown_fn: window.key_click
		keyup_fn: window.key_unclick
	)

	window.ctx = context.Context.create(mut gg_context)

	// Create video struct if we're exporting video.
	if settings.global.video.record {
		window.record = true
		window.video = &export.Video{}
	}

	// Don't record if we're playing the game
	if window.record && argument.play_mode == .play {
		logging.warn('Cannot record while playing the game, only for auto and replays!')
		exit(1)
	}

	// Loads default skin assets
	skin.bind_context(mut window.ctx)

	// Reset global time counter, since we're counting ourselves from this point on.
	if window.record {
		mut g_time := time.get_time()
		g_time.stop()
		g_time.reset()
	}

	// Run the game, blocking, will run until it closes.
	window.ctx.run()

	// We're done recording.
	if window.record {
		window.video.close_pipe_process()
	}
}

// Mountpoint
pub enum PlayState {
	auto
	replay
	play
	tag
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
