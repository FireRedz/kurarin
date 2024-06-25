module ruleset

import math
import sync
import core.osu.parsers.beatmap
import core.osu.parsers.beatmap.object
import core.osu.parsers.beatmap.difficulty
import core.osu.gameplay.cursor
import framework.logging
import framework.math.vector

const tolerance_2b = int(3)
const grades = ['None', 'SSH', 'SS', 'S', 'A', 'B', 'C', 'D']

pub enum Grade {
	@none
	ssh
	ss
	s
	a
	b
	c
	d
}

pub enum Action {
	ignored
	shake
	click
}

pub enum ComboResult {
	reset
	hold
	increase
}

pub struct ButtonState {
pub mut:
	left  bool
	right bool
}

pub fn (state ButtonState) both_released() bool {
	return !(state.left || state.right)
}

pub interface IHitObject {
mut:
	ruleset &Ruleset
	init(&Ruleset, object.IHitObject, []&DifficultyPlayer)
	update_for(&DifficultyPlayer, f64, bool) bool
	update_click_for(&DifficultyPlayer, f64) bool
	update_post_for(&DifficultyPlayer, f64, bool) bool
	update_post(f64) bool
	is_hit(&DifficultyPlayer) bool
	get_number() i64
	get_fade_time() f64
}

type Buttons = i64

const left_mouse = Buttons(1 << 0)
const right_mouse = Buttons(1 << 1)

pub struct DifficultyPlayer {
pub mut:
	cursor            &cursor.Cursor
	diff              difficulty.Difficulty
	double_click      bool
	already_stolen    bool
	buttons           ButtonState
	game_down_state   bool
	mouse_down_button Buttons
	last_button       Buttons
	last_button2      Buttons
	left_cond         bool
	left_cond_e       bool
	right_cond        bool
	right_cond_e      bool
}

pub struct SubSet {
pub mut:
	player    &DifficultyPlayer
	raw_score i64
	accuracy  f64
	max_combo i64
	nobject   i64
	grade     Grade
}

pub struct Ruleset {
pub mut:
	beatmap &beatmap.Beatmap
	cursors []&cursor.Cursor
	subset  []&SubSet

	ended bool

	queue     []IHitObject
	processed []IHitObject

	hit_listener HitListener = dummy_listener

	mutex &sync.Mutex = sync.new_mutex()
}

type HitListener = fn (f64, i64, vector.Vector2[f64], HitResult, ComboResult, i64)

pub fn dummy_listener(_ f64, _ i64, _ vector.Vector2[f64], _ HitResult, _ ComboResult, _ i64) {}

pub fn (mut ruleset Ruleset) set_listener(func HitListener) {
	ruleset.hit_listener = func
}

pub fn (mut ruleset Ruleset) can_be_hit(time f64, mut current_object IHitObject, _player &DifficultyPlayer) Action {
	mut player := &ruleset.subset[0].player

	if mut current_object is Circle {
		mut index := -1

		for i, mut g in ruleset.processed {
			if g.get_number() == current_object.get_number() {
				index = i
			}
		}

		if index > 0
			&& ruleset.beatmap.objects[ruleset.processed[index - 1].get_number()].stack_index > 0
			&& !ruleset.processed[index - 1].is_hit(player) {
			return Action.ignored
		}
	}

	for mut g in ruleset.processed {
		if !g.is_hit(player) {
			if g.get_number() != current_object.get_number() {
				// vfmt off
				if ruleset.beatmap.objects[g.get_number()].get_end_time() + tolerance_2b < ruleset.beatmap.objects[current_object.get_number()].get_start_time() {
					return Action.shake
				}
				// vfmt on
			} else {
				break
			}
		}
	}

	mut hit_range := difficulty.hit_range

	// TODO: Relax
	if false {
		hit_range -= 200.0
	}

	if math.abs[f64](time - ruleset.beatmap.objects[current_object.get_number()].get_start_time()) >= hit_range {
		return Action.shake
	}

	return Action.click
}

pub fn (mut ruleset Ruleset) update(time f64) {
	if ruleset.processed.len > 0 {
		for i := 0; i < ruleset.processed.len; i++ {
			mut g := &ruleset.processed[i]

			is_done := g.update_post(time)

			if is_done {
				ruleset.processed = ruleset.processed[1..]
				i--
			}
		}
	}

	if ruleset.queue.len > 0 {
		for i := 0; i < ruleset.queue.len; i++ {
			mut g := &ruleset.queue[i]

			if g.get_fade_time() > time {
				break
			}

			ruleset.processed << g
			// ruleset.queue = ruleset.queue#[i+i .. i]
			ruleset.queue = ruleset.queue[1..] // TODO: HACk
			i--
		}
	}
}

pub fn (mut ruleset Ruleset) update_click_for(player_cursor &cursor.Cursor, time f64) {
	mut player := &ruleset.subset[0].player

	player.already_stolen = true

	// TODO: Replay/Player
	if true {
		player.left_cond = !player.buttons.left && player.cursor.input.left_button
		player.right_cond = !player.buttons.right && player.cursor.input.right_button

		player.left_cond_e = player.left_cond
		player.right_cond_e = player.right_cond

		if player.buttons.left != player.cursor.input.left_button
			|| player.buttons.right != player.cursor.input.right_button {
			player.game_down_state = player.cursor.input.left_button
				|| player.cursor.input.right_button
			player.last_button2 = player.last_button
			player.last_button = player.mouse_down_button

			player.mouse_down_button = Buttons(0)

			// vfmt off
			if player.cursor.input.left_button {
				player.mouse_down_button |= left_mouse
			}

			if player.cursor.input.right_button {
				player.mouse_down_button |= right_mouse
			}
			// vfmt on
		}
	}

	if ruleset.processed.len > 0 {
		for i := 0; i < ruleset.processed.len; i++ {
			mut g := &ruleset.processed[i]
			g.update_click_for(*player, time)
		}
	}

	// TODO: Replay/Player
	if true {
		player.buttons.left = player.cursor.input.left_button
		player.buttons.right = player.cursor.input.right_button
	}
}

pub fn (mut ruleset Ruleset) update_normal_for(player_cursor &cursor.Cursor, time f64, process_slider_ends_ahead bool) {
	mut player := &ruleset.subset[0].player

	mut was_slider_already := false

	if ruleset.processed.len > 0 {
		for i := 0; i < ruleset.processed.len; i++ {
			mut g := &ruleset.processed[i]

			if mut g is Slider {
				if was_slider_already {
					continue
				}

				if !g.is_hit(player) {
					was_slider_already = true
				}
			}

			g.update_for(*player, time, process_slider_ends_ahead)
		}
	}
}

pub fn (mut ruleset Ruleset) update_post_for(player_cursor &cursor.Cursor, time f64, process_slider_ends_ahead bool) {
	mut player := &ruleset.subset[0].player

	if ruleset.processed.len > 0 {
		for i := 0; i < ruleset.processed.len; i++ {
			mut g := &ruleset.processed[i]

			g.update_post_for(*player, time, process_slider_ends_ahead)
		}
	}
}

pub fn (mut ruleset Ruleset) send_result(time f64, mut player_cursor cursor.Cursor, mut src IHitObject, position vector.Vector2[f64], result HitResult, combo ComboResult) {
	mut number := src.get_number()
	mut subset := &ruleset.subset[0]

	// if result == .ignore || result == .miss {
	// 	if result == .miss && isnil(ruleset.hit_listener) {
	// 		// ruleset.hit_listener(time, number, position, mut ruleset)
	// 	}
	// }

	// FIXME: This is not accurate but i dont care
	subset.raw_score += result.get_value()

	if !isnil(ruleset.hit_listener) {
		ruleset.hit_listener(time, number, position, result, combo, subset.raw_score)
	}
}

// Factory
pub fn new_ruleset(mut loaded_beatmap beatmap.Beatmap, mut cursors []&cursor.Cursor) &Ruleset {
	logging.info('Creating osu! ruleset.')

	mut ruleset := &Ruleset{
		beatmap: unsafe { loaded_beatmap }
	}
	ruleset.cursors = []&cursor.Cursor{}
	ruleset.subset = []&SubSet{}

	// Unsafe: V thinks this is unsafe (which is true), but the list will get overwritten so it's fine.
	mut diff_players := []&DifficultyPlayer{}

	for mut cursor in cursors {
		mut diff := loaded_beatmap.difficulty.Difficulty

		mut player := &DifficultyPlayer{
			cursor: unsafe { *cursor }
			diff: diff
		}

		diff_players << player

		ruleset.cursors << unsafe { *cursor }
		ruleset.subset << &SubSet{
			player: player
		}
	}

	for mut hitobject in loaded_beatmap.objects {
		if mut hitobject is object.Circle {
			mut r_circle := &Circle{}
			r_circle.init(ruleset, hitobject, diff_players)
			ruleset.queue << r_circle
		}

		if mut hitobject is object.Slider {
			mut r_slider := &Slider{}
			r_slider.init(ruleset, hitobject, diff_players)
			ruleset.queue << r_slider
		}
	}

	return ruleset
}
