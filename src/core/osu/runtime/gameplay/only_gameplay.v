module gameplay

import os
import gg
import framework.audio
import framework.audio.common
import framework.graphic.context
import core.common.settings
import core.osu.x
import core.osu.system.skin
import core.osu.parsers.beatmap
import core.osu.parsers.beatmap.object.graphic
import core.osu.gameplay.ruleset
import core.osu.gameplay.cursor
import core.osu.gameplay.overlays

pub enum OSUGameplayMode {
	auto
	replay
	player
}

pub struct OSUGameplay {
pub mut:
	beatmap         &beatmap.Beatmap = unsafe { nil }
	beatmap_audio   &common.ITrack
	beatmap_ruleset &ruleset.Ruleset = unsafe { nil }

	cursor  cursor.ICursorController
	overlay &overlays.GameplayOverlay = unsafe { nil }
}

pub fn (mut osu OSUGameplay) init(mut ctx context.Context, beatmap_lazy &beatmap.Beatmap, mode OSUGameplayMode, replay_path_if_any string) {
	// Init renderer
	// Renderer: Slider
	graphic.init_slider_renderer()

	// Renderer: Skin storage
	skin.set_skin(os.join_path(settings.global.gameplay.paths.skins, settings.global.gameplay.skin.current_skin))
	skin.bind_context(mut ctx)

	// NOTE: Routine starts here.
	osu.beatmap = beatmap_lazy.load_full_beatmap()
	osu.beatmap.bind_context(mut ctx)
	osu.beatmap.reset() // NOTE: This can be delayed.

	osu.beatmap_audio = audio.new_track(osu.beatmap.get_audio_path())
	osu.beatmap_audio.set_volume(f32(settings.global.audio.music * settings.global.audio.global / 10000))

	match mode {
		.player {
			osu.cursor = cursor.make_player_cursor(mut ctx)
		}
		.auto {
			osu.cursor = cursor.make_auto_cursor(mut ctx, osu.beatmap.objects)
		}
		.replay {
			osu.cursor = cursor.make_replay_cursor(mut ctx, replay_path_if_any)
		}
	}

	// FIXME: Ruleset hack.
	mut temp_cursor_hack := [osu.cursor.cursor]
	osu.beatmap_ruleset = ruleset.new_ruleset(mut osu.beatmap, mut temp_cursor_hack)

	// Overlay
	osu.overlay = overlays.new_gameplay_overlay(osu.beatmap_ruleset, osu.cursor.cursor,
		osu.cursor.player, ctx)
}

pub fn (mut osu OSUGameplay) draw(mut ctx context.Context) {
	osu.beatmap.free_slider_attr()

	// Background
	ctx.begin()
	ctx.end()

	// Beatmap & Storyboard
	osu.beatmap.draw()

	osu.overlay.draw()
	osu.cursor.cursor.draw()
}

pub fn (mut osu OSUGameplay) update(time_ms f64, time_delta f64) {
	// Song
	if time_ms >= settings.global.gameplay.playfield.lead_in_time && !osu.beatmap_audio.playing {
		osu.beatmap_audio.set_position(time_ms - settings.global.gameplay.playfield.lead_in_time)
		osu.beatmap_audio.play()
	}

	// Ruleset
	osu.beatmap_ruleset.mutex.@lock()
	osu.beatmap_ruleset.update_click_for(osu.cursor.cursor, time_ms - settings.global.gameplay.playfield.lead_in_time)
	osu.beatmap_ruleset.update_normal_for(osu.cursor.cursor, time_ms - settings.global.gameplay.playfield.lead_in_time,
		false)
	osu.beatmap_ruleset.update_post_for(osu.cursor.cursor, time_ms - settings.global.gameplay.playfield.lead_in_time,
		false)
	osu.beatmap_ruleset.update(time_ms - settings.global.gameplay.playfield.lead_in_time)
	osu.beatmap_ruleset.mutex.unlock()

	// Beatmap
	osu.beatmap.update(time_ms - settings.global.gameplay.playfield.lead_in_time, 1.0)

	// Cursor
	osu.cursor.update(time_ms - settings.global.gameplay.playfield.lead_in_time, time_delta)

	// Overlay
	osu.overlay.update(time_ms - settings.global.gameplay.playfield.lead_in_time)
}

// Events (Key, Mouse)
pub fn (mut osu OSUGameplay) event_keydown(keycode gg.KeyCode) {
	if osu.cursor.cursor.owner != .player {
		return
	}

	osu.beatmap_ruleset.mutex.@lock()

	if keycode == settings.global.gameplay.input.left_key {
		osu.cursor.cursor.input.left_button = true
	}

	if keycode == settings.global.gameplay.input.right_key {
		osu.cursor.cursor.input.right_button = true
	}
	osu.beatmap_ruleset.mutex.unlock()
}

pub fn (mut osu OSUGameplay) event_keyup(keycode gg.KeyCode) {
	if osu.cursor.cursor.owner != .player {
		return
	}

	osu.beatmap_ruleset.mutex.@lock()
	if keycode == settings.global.gameplay.input.left_key {
		osu.cursor.cursor.input.left_button = false
	}

	if keycode == settings.global.gameplay.input.right_key {
		osu.cursor.cursor.input.right_button = false
	}
	osu.beatmap_ruleset.mutex.unlock()
}

pub fn (mut osu OSUGameplay) event_mouse(p_x f32, p_y f32) {
	if osu.cursor.cursor.owner != .player {
		return
	}

	osu.cursor.cursor.position.x = (p_x - x.resolution.offset.x) / x.resolution.playfield_scale
	osu.cursor.cursor.position.y = (p_y - x.resolution.offset.y) / x.resolution.playfield_scale
}
