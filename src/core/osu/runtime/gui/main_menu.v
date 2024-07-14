module gui

import gg
import core.common.settings
import core.osu.parsers.beatmap
import framework.audio
import framework.audio.common
import framework.logging
import framework.graphic.sprite
import framework.math.time
import framework.math.vector

pub struct MainMenu {
mut:
	counter        int
	counter_smooth f64
	window         &GUIWindow
	background     &CustomSpriteManager = &CustomSpriteManager{
	Manager: sprite.make_manager()
}
pub mut:
	current_beatmap &beatmap.BeatmapContainer = unsafe { nil }
	current_version &beatmap.Beatmap = unsafe { nil }
	current_track   &common.ITrack
}

pub fn (mut main_menu MainMenu) change_beatmap(new_beatmap &beatmap.BeatmapContainer) {
	main_menu.counter = 0
	main_menu.current_beatmap = unsafe { new_beatmap }
	main_menu.change_version(main_menu.current_beatmap.versions[0])
}

pub fn (mut main_menu MainMenu) change_version(version &beatmap.Beatmap) {
	logging.info('[${@METHOD}] Changing beatmap to ${version.metadata.title} [${version.metadata.version}]')

	mut need_new_track := true
	mut need_new_background := true

	if !isnil(main_menu.current_version) {
		need_new_track = main_menu.current_version.get_audio_path() != version.get_audio_path()
		need_new_background = main_menu.current_version.get_bg_path() != version.get_bg_path()
	}

	main_menu.current_version = unsafe { version }

	if !isnil(main_menu.current_track) && need_new_track {
		// Old track
		main_menu.current_track.pause()
		main_menu.current_track.set_volume(0.0)
		logging.info('Discarding old track.')
	}

	// New track
	if need_new_track {
		main_menu.current_track = audio.new_track(main_menu.current_version.get_audio_path())
		main_menu.current_track.set_volume(f32(settings.global.audio.music * settings.global.audio.global / 10000))
		main_menu.current_track.set_position(main_menu.current_version.general.preview_time)
		main_menu.current_track.play()
		logging.info('Playing new track.')
	}

	if need_new_background {
		main_menu.background.fadeout_and_die(main_menu.window.time.time, 50.0)

		// Load background and other crap
		mut background := &sprite.Sprite{
			always_visible: true
			textures: [main_menu.window.ctx.create_image(main_menu.current_version.get_bg_path())]
			origin: vector.top_left
		}

		background.add_transform(
			typ: .fade
			time: time.Time{main_menu.window.time.time, main_menu.window.time.time + 50.0}
			before: [195.0]
			after: [255.0]
		)

		background.reset_size_based_on_texture(
			fit_size: true
			source: vector.Vector2[f64]{settings.global.window.width, settings.global.window.height}
		)

		main_menu.background.add(mut background)
	}
}

pub fn (mut main_menu MainMenu) next_version() {
	main_menu.counter++

	if main_menu.counter >= main_menu.current_beatmap.versions.len {
		main_menu.counter = 0
	}

	main_menu.change_version(main_menu.current_beatmap.versions[main_menu.counter])
}

pub fn (mut main_menu MainMenu) prev_version() {
	main_menu.counter--

	if main_menu.counter < 0 {
		main_menu.counter = main_menu.current_beatmap.versions.len - 1
	}

	main_menu.change_version(main_menu.current_beatmap.versions[main_menu.counter])
}

pub fn (mut main_menu MainMenu) update(time_ms f64) {
	main_menu.background.update(time_ms)

	// HACK: simple math hack to smooth out the thing
	main_menu.counter_smooth = f64(main_menu.counter) * 0.05 + main_menu.counter_smooth - main_menu.counter_smooth * 0.05
}

pub fn (mut main_menu MainMenu) draw(arg sprite.CommonSpriteArgument) {
	main_menu.background.draw(arg)

	main_menu.window.ctx.draw_rect_filled(0, 0, int(settings.global.window.width), int(settings.global.window.height),
		gg.Color{0, 0, 0, 100})

	if isnil(main_menu.current_beatmap) {
		return
	}

	// HACK: temporary bullshit color hack
	c_t_temporary_border_color := gg.Color{0, 0, 0, 255}

	// Shapes
	// Triangle transition
	main_menu.window.ctx.draw_triangle_filled(500, 50, 370, 150, 370, 50, gg.Color{0, 0, 0, 255})
	main_menu.window.ctx.draw_triangle_empty(500, 50, 370, 150, 370, 50, c_t_temporary_border_color)

	// Left
	main_menu.window.ctx.draw_rect_filled(0, 0, 370, 150, gg.Color{0, 0, 0, 255})
	main_menu.window.ctx.draw_rect_empty(0, 0, 370, 150, c_t_temporary_border_color)

	// Long
	main_menu.window.ctx.draw_rect_filled(0, 0, int(settings.global.window.width), 100,
		gg.Color{0, 0, 0, 255})
	main_menu.window.ctx.draw_rect_empty(0, 0, int(settings.global.window.width), 100,
		c_t_temporary_border_color)

	// Titles
	main_menu.window.ctx.draw_text(10, 0, '${main_menu.current_version.metadata.artist} - ${main_menu.current_version.metadata.title} [${main_menu.current_version.metadata.version}]',
		color: gg.Color{255, 255, 255, 255}
		size: 32
	)

	main_menu.window.ctx.draw_text(10, 32, 'Mapped by ${main_menu.current_version.metadata.creator}',
		color: gg.Color{255, 255, 255, 255}
		size: 25
	)

	main_menu.window.ctx.draw_text(10, 32 + 25, 'Length: 4:20 BPM: 69 Objects: 420',
		color: gg.Color{255, 255, 255, 255}
		size: 25
	)

	main_menu.window.ctx.draw_text(10, 32 + 25 + 25, 'CS:${main_menu.current_version.difficulty.cs} AR:${main_menu.current_version.difficulty.ar} OD:${main_menu.current_version.difficulty.od} HP:${main_menu.current_version.difficulty.hp} Stars:0.0',
		color: gg.Color{255, 255, 255, 255}
		size: 25
	)

	// Difficulties/Version whatever its called
	for i, version in main_menu.current_beatmap.versions {
		are_we_picking_this_version := version.filename == main_menu.current_version.filename
		y_size := 75
		start_y := int(200.0 + ((f64(i) - main_menu.counter_smooth) * f64(y_size)))

		mut text_color := gg.Color{200, 200, 200, 255}

		if are_we_picking_this_version {
			text_color.r = 255
			text_color.g = 182
			text_color.b = 193
		}

		main_menu.window.ctx.draw_rect_filled(int((settings.global.window.width) * (2.5 / 4)),
			start_y, int(settings.global.window.width), y_size, gg.Color{0, 0, 0, 100})
		main_menu.window.ctx.draw_text(int((settings.global.window.width) * (2.5 / 4)),
			start_y, version.metadata.title,
			color: text_color
			size: 25
		)
		main_menu.window.ctx.draw_text(int((settings.global.window.width) * (2.5 / 4)),
			start_y + 25, '${version.metadata.artist} // ${version.metadata.creator}',
			color: text_color
			size: 20
		)
		main_menu.window.ctx.draw_text(int((settings.global.window.width) * (2.5 / 4)),
			start_y + 20 + 25, version.metadata.version,
			color: text_color
			size: 25
			bold: true
		)
	}

	// Info
	main_menu.window.ctx.draw_text(int(settings.global.window.width) - 100, 32, 'Gameplay Mode: [Press Key]',
		color: gg.Color{255, 255, 255, 255}
		size: 20
		bold: true
		align: .right
	)

	main_menu.window.ctx.draw_text(int(settings.global.window.width) - 100, 32 + 20, 'A - Auto | P - Play | R - Replay',
		color: gg.Color{255, 255, 255, 255}
		size: 20
		bold: true
		align: .right
	)

	main_menu.window.ctx.draw_text(int(settings.global.window.width) - 100, 32 + 20 + 20,
		'Left-Right for beatmap selection',
		color: gg.Color{255, 255, 255, 255}
		size: 20
		bold: true
		align: .right
	)

	main_menu.window.ctx.draw_text(int(settings.global.window.width) - 100, 32 + 20 + 20 + 20,
		'Up-Down for difficulty selection',
		color: gg.Color{255, 255, 255, 255}
		size: 20
		bold: true
		align: .right
	)
}
