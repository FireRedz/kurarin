module cursor

import math
import core.osu.parsers.beatmap
import core.osu.parsers.beatmap.object as gameobject
import core.osu.gameplay.cursor.movers
import framework.math.time
import framework.math.vector
import framework.math.easing

const offset = osu_cursor_trail_delta // 120fps

const tag_on_new_combo = true

// [deprecated: "TODO: remove this after we got realtime auto."]
pub fn make_replay(mut current_beatmap beatmap.Beatmap, mut cursor Cursor, player_number int, max_player int) {
	mut last_object := unsafe { &current_beatmap.objects[0] }
	mut last_position := current_beatmap.objects[0].get_start_position()
	mut direction := 1
	mut counter := 0

	for n, mut object in current_beatmap.objects {
		// vfmt off
		if tag_on_new_combo {
			// vfmt on
			if object.is_new_combo() {
				counter++
			}

			if ((counter - 1) % max_player) != (player_number - 1) {
				continue
			}
		} else {
			// Tag for every N circles
			if ((n + 1) % player_number) != 0 {
				continue
			}
		}

		if mut object is gameobject.Circle || mut object is gameobject.Slider {
			// Color
			cursor.add_transform(
				typ: .color
				easing: easing.linear
				time: time.Time{last_object.time.end, object.time.start}
				before: last_object.color
				after: object.color
			)

			// Movement
			mut mover := movers.get_imover() // linear mover

			if (object.time.start - last_object.time.end) >= 50.0 {
				// Use halfcircle for far objects
				mover = &movers.HalfCircleMover{} // Uncomment to use
			}

			mover.init(mut last_object, mut object, direction)
			direction *= -1 // Invert direction

			// vfmt off
			for i := mover.time.start; i < mover.time.end; i += offset {
				// vfmt on
				position := mover.get_point_at(i)
				cursor.add_transform(
					typ: .move
					easing: easing.quad_out
					// vfmt off
					time: time.Time{i, i + offset}
					// vfmt on
					before: [last_position.x, last_position.y]
					after: [position.x, position.y]
				)
				last_position = position
			}

			// Slider movement
			if mut object is gameobject.Slider {
				// Normal movement
				// vfmt off
				for temp_time := int(object.time.start); temp_time <= int(object.time.end) +
					offset; temp_time += int(offset) {
					times := int(((temp_time - object.time.start) / object.duration) + 1)
					t_time := (f64(temp_time) - object.time.start - (times - 1) * object.duration)
					rt := object.pixel_length / object.curve.length

					mut pos := vector.Vector2[f64]{}
					if (times % 2) == 1 {
						pos = object.curve.point_at(rt * t_time / object.duration)
						last_position = object.curve.point_at(rt * (t_time - offset) / object.duration)
					} else {
						pos = object.curve.point_at((1.0 - t_time / object.duration) * rt)
						last_position = object.curve.point_at((1.0 - (t_time - offset) / object.duration) * rt)
					}
					

					cursor.add_transform(
						typ: .move
						easing: easing.quad_out
						time: time.Time{temp_time, temp_time + offset}
						before: [last_position.x, last_position.y]
						after: [
							pos.x,
							pos.y,
						]
					)
				}
				// vfmt on
			}
		} else if mut object is gameobject.Spinner {
			// oh man here we go agane

			speed := 0.85
			radius := 100.0
			timeframe := 16.6667
			mut rotation := 0.0

			last_position = vector.Vector2[f64]{math.cos(rotation) * radius + 512.0 / 2.0,
				math.sin(rotation) * radius + 384.0 / 2.0}

			for i := object.time.start; i < object.time.end; i += timeframe {
				position := vector.Vector2[f64]{math.cos(rotation) * radius + 512.0 / 2.0,
					math.sin(rotation) * radius + 384.0 / 2.0}

				cursor.add_transform(
					typ: .move
					easing: easing.linear
					time: time.Time{i, i + timeframe}
					before: [last_position.x, last_position.y]
					after: [position.x, position.y]
				)

				rotation += speed
				last_position = position
			}
		}

		last_object = unsafe { object }
	}

	cursor.reset_attributes_based_on_transforms()
}
