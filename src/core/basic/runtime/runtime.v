module runtime

import gg
import framework.math.time
import framework.graphic.window as i_window
import framework.graphic.context

// Simple Basic Window
// emulates how the real game operates but without the game.
// to get the baseline performance of the whole thing,
// just in case theres some dumb internal overhead.
@[heap]
pub struct Window {
	i_window.GeneralWindow
}

pub fn (mut window Window) init(_ voidptr) {
	context.vsync(false)

	spawn fn (mut window Window) {
		mut g_time := time.get_time()
		mut limiter := time.Limiter{1000, 0, 0}

		g_time.reset()
		g_time.set_speed(1.0)

		for {
			window.mutex.@lock()
			window.update(g_time.time, g_time.delta)
			window.mutex.unlock()

			window.GeneralWindow.tick_update()
			limiter.sync()
		}
	}(mut window)
}

pub fn (mut window Window) update(update_time f64, delta f64) {
	// Nothing.
}

pub fn (mut window Window) draw(_ voidptr) {
	window.mutex.@lock()

	window.ctx.begin()
	window.tick_draw()
	window.GeneralWindow.draw_branding()
	window.GeneralWindow.draw_stats()
	window.ctx.end()

	window.mutex.unlock()
}

pub fn run() {
	mut window := &Window{}

	mut gg_context := gg.new_context(
		width: 1280
		height: 720
		user_data: window
		// FNs
		init_fn: window.init
		frame_fn: window.draw
	)

	window.ctx = context.Context.create(mut gg_context)
	window.ctx.run()
}
