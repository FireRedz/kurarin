module cursor

import math
import core.osu.parsers.beatmap.object
import core.osu.gameplay.cursor.movers
import framework.math.vector
import core.osu.system.player
import framework.graphic.context

pub struct AutoCursor {
pub mut:
	cursor  &Cursor
	mover   &movers.AggressiveMover = &movers.AggressiveMover{}
	queue   []object.IHitObject
	queue_i int
	// Keys logic
	last_time        f64
	previous_end     f64
	release_left_at  f64 = -123456
	release_right_at f64 = -123456
	was_right_before bool
	// Spinner
	rotation f64
	// Cursor-dance crap
	mover_path int = 1
	// Info
	player player.Player = player.Player{
		name: 'Suigintou'
	}
}

pub fn (mut auto AutoCursor) update(time f64, delta f64) {
	// Auto
	// Looks abit janky compared to the pregenerated one.
	if auto.queue_i < auto.queue.len {
		mut current_object := &auto.queue[auto.queue_i]
		if auto.last_time < current_object.get_start_time()
			&& time >= current_object.get_start_time() {
			// Update keys
			start_time := current_object.get_start_time()
			end_time := current_object.get_end_time()

			mut release_at := end_time + 50.0

			if auto.queue_i + 1 < auto.queue.len {
				n_time := auto.queue[math.min[int](auto.queue_i + 2, auto.queue.len - 1)].get_start_time()
				release_at = math.clamp(n_time - 2.0, end_time + 1.0, release_at)
			}

			should_be_right := !auto.was_right_before && start_time - auto.previous_end < 140.0

			if should_be_right {
				auto.release_right_at = release_at
			} else {
				auto.release_left_at = release_at
			}

			auto.was_right_before = should_be_right
			auto.previous_end = end_time
		}

		if auto.queue[auto.queue_i].time.start <= time {
			if time > auto.queue[auto.queue_i].time.end {
				auto.queue_i++
				if auto.queue_i + 1 < auto.queue.len {
					auto.mover.init(mut &auto.queue[auto.queue_i - 1], mut &auto.queue[auto.queue_i],
						auto.mover_path)

					// Negate, so it goes left right left right ....
					auto.mover_path = auto.mover_path * -1

					// Reset spinner rotation
					auto.rotation = 0.0
				} else {
					// End of the map
					// Just move to the last object no matter what
					auto.queue_i = auto.queue.len - 1
				}
			}
		}

		mover_time := time - auto.mover.time.start
		// Apply the position
		if mover_time >= 0.0 {
			// HitCircle mover
			if time <= auto.mover.time.end {
				pos := auto.mover.get_point_at(time)
				auto.cursor.position.x = pos.x
				auto.cursor.position.y = pos.y
			}

			// Some object specific movement
			mut cur_hitobject := &auto.queue[auto.queue_i]

			// Set cursor to object start position if first object.
			if auto.queue_i == 0 {
				auto.cursor.position.x = cur_hitobject.position.x
				auto.cursor.position.y = cur_hitobject.position.y
			}

			// Slider
			if (time >= auto.mover.time.end && time <= cur_hitobject.time.end)
				&& mut cur_hitobject is object.Slider {
				auto.cursor.position.x = cur_hitobject.slider_b_sprite.position.x
				auto.cursor.position.y = cur_hitobject.slider_b_sprite.position.y
			}

			// Spinner
			if (time >= auto.mover.time.end + 10.0 && time >= cur_hitobject.time.start
				&& time <= cur_hitobject.time.end) && mut cur_hitobject is object.Spinner {
				radius := 100.0
				position := vector.Vector2[f64]{math.cos(auto.rotation) * radius + 512.0 / 2.0,
					math.sin(auto.rotation) * radius + 384.0 / 2.0}
				auto.cursor.position.x = position.x
				auto.cursor.position.y = position.y
				auto.rotation += 0.85
			}
		}
	}

	auto.cursor.update(time, delta) // Trails

	auto.cursor.input.left_button = time < auto.release_left_at
	auto.cursor.input.right_button = time < auto.release_right_at
	auto.last_time = time
}

pub fn make_auto_cursor(mut ctx context.Context, hitobjects []object.IHitObject) &AutoCursor {
	mut auto := &AutoCursor{
		cursor: make_cursor(mut ctx)
		queue: hitobjects
	}

	auto.cursor.position.x = 512.0 / 2.0
	auto.cursor.position.y = 384.0 / 2.0

	return auto
}
