// TODO: move this somewhere else

module cursor

import gx
import sync
import framework.graphic.sprite
import framework.graphic.context
import core.osu.graphics
import core.common.settings

const max_valid_style = 2
const osu_cursor_trail_delta = f64(1000.0 / 120.0) // 120FPS

pub enum CursorController {
	player
	bot
}

pub struct CursorInput {
pub mut:
	left_button  bool
	right_button bool

	left_mouse  bool
	right_mouse bool
}

pub struct Cursor {
	sprite.Sprite
mut:
	renderer sprite.ISprite
	mutex    &sync.Mutex      = sync.new_mutex()
	ctx      &context.Context = unsafe { nil }
pub mut:
	owner CursorController = .bot
	input CursorInput

	trail_color gx.Color = gx.Color{0, 25, 100, u8(255 * 0.5)}
}

pub fn (mut cursor Cursor) draw(arg sprite.CommonSpriteArgument) {
	cursor.mutex.@lock()
	cursor.renderer.draw(ctx: cursor.ctx)
	cursor.mutex.unlock()
}

pub fn (mut cursor Cursor) update(update_time f64, _delta f64) {
	cursor.mutex.@lock()
	cursor.Sprite.update(update_time) // Update the main cursor itself

	cursor.renderer.color = cursor.trail_color
	cursor.renderer.position = cursor.position
	cursor.renderer.update(update_time)

	cursor.mutex.unlock()
}

// Factory
pub fn make_cursor(mut ctx context.Context) &Cursor {
	mut cursor := &Cursor{
		ctx: ctx
		always_visible: true
		renderer: graphics.DebugCursor.create()
	}

	match int(settings.global.gameplay.skin.cursor.style) {
		-1 {
			cursor.renderer = graphics.DebugCursor.create()
		}
		0, 1 {
			cursor.renderer = graphics.PeppyCursor.create()
		}
		2 {
			cursor.renderer = graphics.DanserCursor.create()
		}
		else {
			panic('Invalid cursor style selected, only supports 0 and 1.')
		}
	}
	return cursor
}
