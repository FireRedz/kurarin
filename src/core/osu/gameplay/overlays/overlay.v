module overlays

// import gx
import math
import core.osu.x
import core.osu.system.skin
import core.osu.system.player
import core.osu.gameplay.cursor
import core.osu.gameplay.ruleset
import core.common.settings
import framework.logging
import framework.math.time
import framework.math.vector
import framework.graphic.sprite
import framework.graphic.context
import core.osu.gameplay.overlays.gameplay

const g_overlay_hack = &GameplayOverlay{
	ctx: unsafe { 0 }
	ruleset: unsafe { 0 }
	cursor: unsafe { 0 }
	hitresult: unsafe { 0 }
	combo_counter: unsafe { 0 }
	scoreboard: unsafe { 0 }
}

pub struct GameplayOverlay {
pub mut:
	last_time f64
	combo     i64
	new_combo i64

	score        i64
	score_smooth i64
	score_font   &sprite.NumberSprite = unsafe { nil }

	ruleset &ruleset.Ruleset
	cursor  &cursor.Cursor

	key_states      [4]bool
	key_counters    [4]int
	last_presses    [4]f64
	keys_background &sprite.Sprite = unsafe { nil }
	keys            []&sprite.Sprite
	keys_font       &sprite.NumberSprite = unsafe { nil }

	ctx &context.Context
	//
	hitresult     &gameplay.HitResults
	combo_counter &gameplay.ComboCounter
	scoreboard    &gameplay.ScoreBoard
}

pub fn (mut overlay GameplayOverlay) update(_time f64) {
	overlay.combo_counter.update(_time)
	overlay.hitresult.update(_time)
	overlay.scoreboard.update(_time)

	for mut sprite in overlay.keys {
		sprite.update(_time)
	}

	// KEYs
	current_states := [overlay.cursor.input.left_button, overlay.cursor.input.right_button]!

	for i, state in current_states {
		mut color := [255.0, 222.0, 0.0]

		if i > 1 {
			color = [248.0, 0.0, 158.0]
		}

		if !overlay.key_states[i] && state {
			mut key := &overlay.keys[i]

			key.remove_transform_by_type(.scale_factor)
			key.add_transform(
				typ: .scale_factor
				time: time.Time{_time, _time + 100.0}
				before: [
					1.0,
				]
				after: [0.8]
			)
			key.add_transform(
				typ: .color
				time: time.Time{_time, _time + 100.0}
				before: [
					255.0,
					255.0,
					255.0,
				]
				after: color
			)

			overlay.key_counters[i]++
			overlay.last_presses[i] = _time + 100.0
		}

		if overlay.key_states[i] && !state {
			mut key := &overlay.keys[i]

			key.remove_transform_by_type(.scale_factor)
			key.add_transform(
				typ: .scale_factor
				time: time.Time{math.max[f64](_time, overlay.last_presses[i]), _time + 100.0}
				before: [key.size.y / key.raw_size.y]
				after: [
					1.0,
				]
			)
			key.add_transform(
				typ: .color
				time: time.Time{_time, _time + 100.0}
				before: color
				after: [
					255.0,
					255.0,
					255.0,
				]
			)
		}

		overlay.key_states[i] = state
	}

	overlay.score_font.update(_time)
	overlay.last_time = _time
}

pub fn (mut overlay GameplayOverlay) draw() {
	overlay.hitresult.draw()
	overlay.keys_background.draw(time: overlay.last_time, ctx: overlay.ctx)

	for i, mut sprite in overlay.keys {
		// Sprite
		sprite.draw(time: overlay.last_time, ctx: overlay.ctx)

		// Text
		pos_x := settings.global.window.width - 24 * x.resolution.ui_camera.scale
		pos_y := (settings.global.window.height / 2.0 - 64 + (30.4 +
			f64(i) * 47.2) * x.resolution.ui_camera.scale)
		scale := (sprite.size.y / sprite.raw_size.y) * x.resolution.ui_camera.scale

		overlay.keys_font.draw_number(overlay.key_counters[i].str(), vector.Vector2[f64]{pos_x, pos_y},
			vector.centre,
			time: overlay.last_time
			ctx: overlay.ctx
			scale: scale
		)
	}

	overlay.combo_counter.draw(ctx: overlay.ctx, scale: x.resolution.ui_camera.scale)

	// Score
	overlay.score_smooth = i64(f64(overlay.score) * 0.5 + f64(overlay.score_smooth) - f64(overlay.score_smooth) * 0.5)
	overlay.score_font.draw_number('${overlay.score_smooth:08d}', vector.Vector2[f64]{settings.global.window.width - 5 - (8 * (overlay.score_font.size.x * x.resolution.ui_camera.scale)), 0},
		vector.top_left,
		ctx: overlay.ctx
		time: overlay.last_time
		scale: x.resolution.ui_camera.scale
	)

	// Scoreboard
	overlay.scoreboard.draw(ctx: overlay.ctx, scale: x.resolution.ui_camera.scale)
}

pub fn new_gameplay_overlay(player_ruleset &ruleset.Ruleset, player_cursor &cursor.Cursor, player_info player.Player, ctx &context.Context) &GameplayOverlay {
	logging.debug('[Overlay] Creating for player: ${player_info.name}')

	logging.debug('[Overlay] Stage 0')
	mut hitresult := gameplay.make_hit_result(ctx, player_ruleset.beatmap.difficulty.Difficulty)
	logging.debug('[Overlay] Stage 0.1')
	mut counter := gameplay.make_combo_counter()
	logging.debug('[Overlay] Stage 0.2')
	mut score_font := sprite.make_number_font(skin.global.meta.score_prefix)
	logging.debug('[Overlay] Stage 0.3')

	logging.debug('[Overlay] Stage 1')

	mut overlay := &GameplayOverlay{
		ruleset: unsafe { player_ruleset }
		cursor: unsafe { player_cursor }
		ctx: unsafe { ctx }
		hitresult: hitresult
		combo_counter: counter
		score_font: score_font
		scoreboard: unsafe { 0 }
	}

	mut scoreboard := gameplay.make_score_board(overlay, counter, player_info)
	overlay.scoreboard = scoreboard

	overlay.keys_background = &sprite.Sprite{
		origin: vector.top_left
		always_visible: true
	}
	overlay.keys_background.add_transform(
		typ: .move
		time: time.Time{0.0, 0.0}
		before: [
			settings.global.window.width,
			settings.global.window.height / 2.0 - 64.0,
		]
	)
	overlay.keys_background.add_transform(
		typ: .angle
		time: time.Time{0.0, 0.0}
		before: [
			math.pi / 2.0,
		]
	)
	overlay.keys_background.add_transform(
		typ: .scale
		time: time.Time{0.0, 0.0}
		before: [
			1.05,
			1.0,
		]
	)
	overlay.keys_background.textures << skin.get_texture('inputoverlay-background')
	overlay.keys_background.reset_size_based_on_texture(factor: x.resolution.ui_camera.scale)
	overlay.keys_background.reset_attributes_based_on_transforms()

	// Input keys
	for i in 0 .. 4 {
		// Key
		pos_y := settings.global.window.height / 2.0 - 64.0 + (30.4 +
			f64(i) * 47.2) * x.resolution.ui_camera.scale

		mut key := &sprite.Sprite{}
		key.add_transform(
			typ: .move
			time: time.Time{0.0, 0.0}
			before: [
				settings.global.window.width - 24.0 * x.resolution.ui_camera.scale,
				pos_y,
			]
		)
		key.textures << skin.get_texture('inputoverlay-key')
		key.always_visible = true
		key.reset_size_based_on_texture(factor: x.resolution.ui_camera.scale)
		key.reset_attributes_based_on_transforms()

		overlay.keys << key
	}

	// Number
	overlay.keys_font = sprite.make_number_sprite(0, 'default')
	overlay.keys_font.always_visible = true
	overlay.keys_font.reset_size_based_on_texture(factor: x.resolution.ui_camera.scale / 4.0)
	overlay.keys_font.reset_attributes_based_on_transforms()

	overlay.ruleset.set_listener(hit_received)

	// HACK: bruh
	unsafe {
		overlays.g_overlay_hack = overlay
	}
	return overlay
}

// Some hack
pub fn hit_received(current_time f64, number i64, position vector.Vector2[f64], result ruleset.HitResult, combo ruleset.ComboResult, score i64) {
	mut g_overlay := unsafe { overlays.g_overlay_hack }
	g_overlay.score = score
	g_overlay.hitresult.add_result(current_time, result, position)

	if combo == .increase {
		g_overlay.combo_counter.increase()
	} else if combo == .reset {
		g_overlay.combo_counter.reset()
	}
}
