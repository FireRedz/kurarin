module runtime

import gg
import core.osu.x

pub fn (mut window Window) mouse_move(x_pos f32, y_pos f32, _ voidptr) {
	if window.argument.play_mode != .play {
		return
	}

	window.cursors[0].position.x = (x_pos - x.resolution.offset.x) / x.resolution.playfield_scale
	window.cursors[0].position.y = (y_pos - x.resolution.offset.y) / x.resolution.playfield_scale
}

pub fn (mut window Window) mouse_scroll(ev &gg.Event, _ voidptr) {
	// C.mu_input_scroll(&window.microui.ctx, -ev.scroll_x, -ev.scroll_y * 6)
}

pub fn (mut window Window) mouse_click(pos_x f32, pos_y f32, button gg.MouseButton, _ voidptr) {
	// C.mu_input_mousedown(&window.microui.ctx, int(x), int(y), int(button) + 1)
}

pub fn (mut window Window) mouse_unclick(pos_x f32, pos_y f32, button gg.MouseButton, _ voidptr) {
	// C.mu_input_mouseup(&window.microui.ctx, int(x), int(y), int(button) + 1)
}

pub fn (mut window Window) key_click(keycode gg.KeyCode, modifier gg.Modifier, _ voidptr) {
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

pub fn (mut window Window) key_unclick(keycode gg.KeyCode, modifier gg.Modifier, _ voidptr) {
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
