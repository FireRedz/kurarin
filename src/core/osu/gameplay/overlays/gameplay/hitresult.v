module gameplay

import rand
import framework.logging
import framework.math.time
import framework.math.vector
import framework.graphic.sprite
import framework.graphic.context
import core.osu.x
import core.osu.system.skin
import core.osu.gameplay.ruleset
// import core.osu.parsers.beatmap.object
import core.osu.parsers.beatmap.difficulty

pub struct HitResults {
pub mut:
	ctx       &context.Context
	sprites   []&sprite.Sprite
	diff      difficulty.Difficulty
	last_time f64
	ratio     f64
}

pub fn make_hit_result(ctx &context.Context, diff difficulty.Difficulty) &HitResults {
	logging.debug('[HitResult] Difficulty: ${diff}')

	mut hitresult := &HitResults{
		ctx: unsafe { ctx }
		diff: diff
	}
	hitresult.ratio = f64((hitresult.diff.circle_radius * 1.05 * 2) / 128)

	return hitresult
}

pub fn (mut result HitResults) add_result(_time f64, _result ruleset.HitResult, position vector.Vector2[f64]) {
	mut tex_name := ''

	match _result {
		.hit300 { tex_name = 'hit300' }
		.hit100 { tex_name = 'hit100' }
		.hit50 { tex_name = 'hit50' }
		.miss { tex_name = 'hit0' }
		else {}
	}

	if tex_name == '' {
		return
	}

	// Animation
	mut hit := &sprite.Sprite{}
	hit.textures << skin.get_frames(tex_name)

	if hit.textures.len > 1 {
		// TODO: read skin.ini file for animation fps
		hit.texture_fps = 60
	}

	// Animation
	fade_in := _time + difficulty.result_fade_in
	post_empt := _time + difficulty.post_empt
	fade_out := post_empt + difficulty.result_fade_out

	hit.add_transform(typ: .move, time: time.Time{_time, _time}, before: [position.x, position.y])
	hit.add_transform(
		typ: .fade
		time: time.Time{_time, fade_in}
		before: [0.0]
		after: [
			255.0,
		]
	)
	hit.add_transform(
		typ: .fade
		time: time.Time{post_empt, fade_out}
		before: [
			255.0,
		]
		after: [0.0]
	)

	hit.add_transform(
		typ: .scale_factor
		time: time.Time{_time, _time + difficulty.result_fade_in * 0.8}
		before: [0.6]
		after: [1.1]
	)
	hit.add_transform(
		typ: .scale_factor
		time: time.Time{fade_in, _time + difficulty.result_fade_in * 1.2}
		before: [1.1]
		after: [0.9]
	)
	hit.add_transform(
		typ: .scale_factor
		time: time.Time{_time + difficulty.result_fade_in * 1.2, _time +
			difficulty.result_fade_in * 1.4}
		before: [0.9]
		after: [1.0]
	)

	if _result == .miss {
		rotation := rand.f64() * 0.3 - 0.15

		hit.add_transform(
			typ: .angle
			time: time.Time{_time, fade_in}
			before: [0.0]
			after: [
				rotation,
			]
		)
		hit.add_transform(
			typ: .angle
			time: time.Time{fade_in, fade_out}
			before: [
				rotation,
			]
			after: [rotation * 2.0]
		)

		hit.add_transform(
			typ: .move_y
			time: time.Time{_time, fade_out}
			before: [
				position.y - 5.0,
			]
			after: [position.y + 40.0]
		)
	}

	hit.reset_size_based_on_texture(factor: result.ratio)
	hit.reset_attributes_based_on_transforms()

	result.sprites << hit
}

pub fn (mut result HitResults) update(update_time f64) {
	for mut sprite in result.sprites {
		sprite.update(update_time)
	}
	result.last_time = update_time
}

pub fn (mut result HitResults) draw() {
	for mut sprite in result.sprites {
		sprite.draw(time: result.last_time, ctx: result.ctx, camera: x.resolution.camera)
	}
}
