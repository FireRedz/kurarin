module cursor

import core.osu.system.player
import framework.math.time
import framework.graphic.context
import core.osu.parsers.replay as i_replay

const osu_m1 = 1 << 0
const osu_m2 = 1 << 1
const osu_k1 = 1 << 2
const osu_k2 = 1 << 3

pub struct ReplayEvent {
pub:
	time f64
	keys int
}

pub struct ReplayCursor {
pub mut:
	cursor &Cursor
	player player.Player

	keys   [4]bool
	events []ReplayEvent
}

pub fn (mut replay ReplayCursor) update(update_time f64, update_delta f64) {
	for i := 0; i < replay.events.len; i++ {
		if update_time >= replay.events[i].time {
			keys := replay.events[i].keys

			replay.cursor.input.left_button = (keys & cursor.osu_m1) == cursor.osu_m1
				|| (keys & cursor.osu_k1) == cursor.osu_k1
			replay.cursor.input.right_button = (keys & cursor.osu_m2) == cursor.osu_m2
				|| (keys & cursor.osu_k2) == cursor.osu_k2

			replay.events = replay.events[1..]
		}
	}

	replay.cursor.update(update_time, update_delta)
}

pub fn make_replay_cursor(mut ctx context.Context, path_to_replay string) &ReplayCursor {
	mut auto := &ReplayCursor{
		cursor: make_cursor(mut ctx)
	}

	auto.cursor.position.x = 512.0 / 2.0
	auto.cursor.position.y = 384.0 / 2.0

	// Read crap
	mut replay_parser := i_replay.Replay{}
	replay_parser.load(path_to_replay)

	auto.player = replay_parser.player

	mut replay_time := 0.0
	mut last_pos := [0.0, 0.0]

	for action in replay_parser.frames {
		delta := action.delta
		replay_time += delta

		// Movement
		current_x := action.position[0]
		current_y := action.position[1]

		auto.cursor.add_transform(
			typ: .move
			time: time.Time{replay_time - delta, replay_time}
			before: [
				last_pos[0],
				last_pos[1],
			]
			after: [current_x, current_y]
		)

		last_pos[0] = current_x
		last_pos[1] = current_y

		// Keys
		keys := action.keys

		auto.events << ReplayEvent{
			time: replay_time
			keys: keys
		}
	}

	// Filter out retarded keys event
	auto.events = auto.events.filter(it.time >= 0.0)

	return auto
}
