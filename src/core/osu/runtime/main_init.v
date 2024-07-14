module runtime

import core.common.settings // Load this first
import core.osu.gameplay.cursor
import framework.math.time
import framework.math.vector
import framework.graphic.visualizer

pub fn (mut window Window) initialize_audio_visualizer() {
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

pub fn (mut window Window) initialize_player() {
	match window.argument.play_mode {
		.play {
			window.cursors << cursor.make_cursor(mut window.ctx)
		}
		.replay {
			window.cursor_controller = cursor.make_replay_cursor(mut window.ctx, window.argument.replay_path)
			window.current_player = window.cursor_controller.player
			window.cursors << unsafe { window.cursor_controller.cursor }
		}
		.tag {
			panic('Unimplemented!')
		}
		else {
			window.cursor_controller = cursor.make_auto_cursor(mut window.ctx, window.beatmap.objects)
			window.current_player = window.cursor_controller.player
			window.cursors << unsafe { window.cursor_controller.cursor }
		}
	}
}

pub fn (mut window Window) initialize_recording() {
	window.video.init_video_pipe_process()
	window.video.init_audio_pipe_process()

	mut g_time := time.get_time()
	g_time.set_speed(settings.global.window.speed)
	g_time.use_custom_delta = true
	g_time.custom_delta = 1000.0 / settings.global.video.fps
}
