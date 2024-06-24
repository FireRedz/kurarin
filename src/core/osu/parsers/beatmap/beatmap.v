module beatmap

import os
import math
import core.osu.parsers.beatmap.difficulty
import core.osu.parsers.beatmap.timing
import core.osu.parsers.beatmap.object
import gx
import sokol.gfx
import sokol.sgl
import sokol.sapp
import framework.ffmpeg
import framework.logging
import framework.math.time
import framework.math.vector
import framework.graphic.sprite
import framework.graphic.context
import core.osu.x
import core.osu.system.skin
import core.osu.system.audio
import core.common.settings
import core.osu.parsers.beatmap.storyboard
import core.osu.parsers.beatmap.object.graphic

pub struct BeatmapGeneralInfo {
pub mut:
	bg_filename    string @[_SKIP]
	video_filename string @[_SKIP]
	video_offset   f64    @[_SKIP]
	audio_filename string @[AudioFilename]
	stack_leniency f64    @[StackLeniency]
	widescreen     bool   @[WidescreenStoryboard]
	preview_time   f64    @[PreviewTime]
}

pub struct BeatmapMetadataInfo {
pub mut:
	title   string @[Title]
	artist  string @[Artist]
	version string @[Version]
	creator string @[Creator]
	id      int    @[BeatmapID]
}

pub struct BeatmapDifficultyInfo {
	difficulty.Difficulty
}

pub struct Beatmap {
pub mut:
	root       string
	filename   string
	time       time.Time
	general    BeatmapGeneralInfo
	metadata   BeatmapMetadataInfo
	difficulty BeatmapDifficultyInfo
	timing     timing.Timings

	ctx         &context.Context       = unsafe { nil }
	storyboard  &storyboard.Storyboard = &storyboard.Storyboard{}
	background  []sprite.ISprite
	objects     []object.IHitObject
	queue       []object.IHitObject
	finished    []object.IHitObject
	combo_color []gx.Color
	objects_i   int
	// Temporary
	playfield_size  vector.Vector2[f64]
	temp_beatmap_sb []string
	last_update     f64
	last_boost      f64
	// vfmt off
	to_be_freed []&graphic.SliderRendererAttr
	// vfmt on
}

// General Helper
pub fn (beatmap &Beatmap) load_full_beatmap() &Beatmap {
	// We load a new beatmap with everything loaded, to be use with lazy beatmap loading.
	return parse_beatmap(os.join_path(beatmap.root, beatmap.filename), false)
}

// Method
pub fn (mut beatmap Beatmap) bind_context(mut ctx context.Context) {
	beatmap.ctx = unsafe { ctx }
}

pub fn (mut beatmap Beatmap) ensure_background_loaded() {
	if beatmap.storyboard.manager.queue.len == 0 || beatmap.storyboard.no_background_layer_found {
		// Video
		mut has_video := false
		if beatmap.general.video_filename.len != 0 && os.exists(beatmap.get_video_path())
			&& settings.global.gameplay.playfield.background.enable_video {
			has_video = true
			mut video := ffmpeg.make_video_sprite(beatmap.get_video_path(), mut beatmap.ctx,
				beatmap.general.video_offset)
			beatmap.storyboard.video = video
		}

		// Nothing on the storyboard, make our own background
		image := beatmap.ctx.create_image(beatmap.get_bg_path())
		mut ratio := ((480.0 * (16.0 / 9.0)) / f64(image.width))

		// Fit the image height also
		for (f64(image.height) * ratio) < 480 {
			ratio += 0.05
		}

		end_size := vector.Vector2[f64]{f64(image.width * ratio), f64(image.height * ratio)}

		mut beatmap_bg := &sprite.Sprite{
			origin: vector.centre
			textures: [image]
			always_visible: true
			position: vector.Vector2[f64]{320.0, 240.0}
		}

		// fade
		beatmap_bg.add_transform(
			typ: .fade
			time: time.Time{-1500, -500}
			before: [
				0.0,
			]
			after: [255.0]
		)

		if has_video {
			beatmap_bg.add_transform(
				typ: .fade
				time: time.Time{1100, 1200}
				before: [
					0.0,
				]
			)
			beatmap_bg.always_visible = false
		}

		// done
		beatmap_bg.reset_size_based_on_texture(size: end_size)
		beatmap_bg.reset_attributes_based_on_transforms()

		beatmap.storyboard.manager.add_front(mut beatmap_bg)
		logging.info('No background, making one!')
	}
}

pub fn (mut beatmap Beatmap) ensure_hitsound_loaded() {
	logging.debug('Loading hitsounds!')
	audio.init_samples(skin.get_skin().fallback, beatmap.root)
	logging.debug('Loaded hitsound')
}

pub fn (mut beatmap Beatmap) reset() {
	// Normal shit
	beatmap.process_stack_position()

	// Check for combo colors
	if beatmap.combo_color.len == 0 {
		beatmap.combo_color << gx.Color{255, 255, 255, 255}
	}

	mut combo_number := 1
	mut combo_color := 0
	mut combo_color_hax := 0
	for i, mut o in beatmap.objects {
		if o.is_new_combo() {
			combo_number = 1
			combo_color++
			combo_color_hax += o.color_offset + 1
		}

		// NOTE
		// * use combo_color for default color (skin, todo)
		// * use combo_color_hax for beatmap color

		// Set colors
		mut color := beatmap.combo_color[combo_color_hax % beatmap.combo_color.len]

		if settings.global.gameplay.skin.use_colors_from_skin
			&& skin.global.meta.combo_colors.len > 0 {
			color = skin.global.meta.combo_colors[combo_color_hax % skin.global.meta.combo_colors.len]
		}

		o.color = [f64(color.r), f64(color.g), f64(color.b)]

		o.set_id(i)
		o.set_combo_number(combo_number)
		o.set_timing(beatmap.timing)
		o.set_difficulty(beatmap.difficulty.Difficulty)

		combo_number++
	}

	// Storyboard
	beatmap.storyboard = storyboard.parse_storyboard(beatmap.get_sb_path(), mut beatmap.ctx)

	beatmap.storyboard.initialize_camera()
	beatmap.ensure_hitsound_loaded()

	if settings.global.gameplay.playfield.background.enable_storyboard {
		beatmap.storyboard.parse_lines(beatmap.temp_beatmap_sb) // Parse beatmap's storyboard too (if theres any)
		beatmap.storyboard.parse_lines((os.read_file(beatmap.get_sb_path()) or { '' }).split('\n'))
		logging.info('Storyboard loaded!')
	}

	beatmap.ensure_background_loaded()

	// // Only start thread when needed and not recording
	if beatmap.storyboard.manager.queue.len > 0 && !settings.global.video.record {
		beatmap.storyboard.start_thread()
	}

	// Set beatmap time
	for mut object in beatmap.objects {
		beatmap.time.start = math.min[f64](object.get_start_time(), beatmap.time.start)
		beatmap.time.end = math.max[f64](object.get_end_time(), beatmap.time.end)
	}
}

pub fn (mut beatmap Beatmap) update(update_time f64, boost f32) {
	// Update shit
	beatmap.last_update = update_time
	beatmap.last_boost = boost

	// Storyboard
	beatmap.storyboard.update_time(update_time)
	beatmap.storyboard.update_boost(beatmap.last_boost)

	// Update storyboard in beatmap thread if recording instead
	if settings.global.video.record {
		beatmap.storyboard.update(update_time)
	}

	// Update hitobjects
	for i := beatmap.objects_i; i < beatmap.objects.len; i++ {
		if update_time >= (beatmap.objects[i].get_start_time() - beatmap.difficulty.preempt)
			&& update_time <= (beatmap.objects[i].get_end_time() + difficulty.hit_fade_out + beatmap.difficulty.hit50) {
			// logging.debug("Added hitobject ${i} into queue")
			beatmap.queue << &beatmap.objects[i]
			beatmap.objects_i++
			continue
		}
	}

	// Queue
	for i := 0; i < beatmap.queue.len; i++ {
		// Remove if ended
		if update_time >= (beatmap.queue[i].get_end_time() + (difficulty.hit_fade_out * 3.0)) {
			// logging.debug("Removed hitobject ${i} from queue.")
			beatmap.finished << &beatmap.queue[i]

			// Special case
			mut obj := &beatmap.queue[i]
			if mut obj is object.Slider {
				beatmap.to_be_freed << obj.slider_renderer_attr
			}

			beatmap.queue = beatmap.queue[1..]
			i--
			continue
		}

		beatmap.queue[i].update(update_time)
		beatmap.queue[i].set_boost_level(f32(beatmap.last_boost))
	}

	// Slider renderer scale
	graphic.update_boost_level(f32(beatmap.last_boost))

	// Playfield size update
	// TODO: make this customizeable or smth
	// Since this is math based animation instead of transformation (if that makes sense), we need to set the actual size after the lead_in_time ends
	if beatmap.last_update + settings.global.gameplay.playfield.lead_in_time >= settings.global.gameplay.playfield.lead_in_time - 2000
		&& beatmap.last_update + settings.global.gameplay.playfield.lead_in_time < settings.global.gameplay.playfield.lead_in_time {
		beatmap.playfield_size.x = x.resolution.playfield.x * 0.25 + beatmap.playfield_size.x - beatmap.playfield_size.x * 0.25
		beatmap.playfield_size.y = x.resolution.playfield.y * 0.25 + beatmap.playfield_size.y - beatmap.playfield_size.y * 0.25
	} else if beatmap.last_update + settings.global.gameplay.playfield.lead_in_time > settings.global.gameplay.playfield.lead_in_time {
		// Over the lead_in_time, put actual size
		beatmap.playfield_size.x = x.resolution.playfield.x
		beatmap.playfield_size.y = x.resolution.playfield.y
	}

	// last
	beatmap.post_update(update_time)

	// Done
}

pub fn (mut beatmap Beatmap) post_update(update_time f64) {
	// Note that this only used for freeing slider (cuz we're using shaders, vertex and stuff and those eat lots of ram)
	// and also for some reason sokol doesnt support freeing it (maybe it does) on another thread, its only working
	// when we freeing it on draw calls /shrug pretty weird ngl
	// EDIT: ignore what i said earlier
	for i := 0; i < beatmap.finished.len; i++ {
		beatmap.finished[i].post_update(update_time)
		beatmap.finished = beatmap.finished[1..]
		i--
	}
}

pub fn (mut beatmap Beatmap) free_slider_attr() {
	// Special
	for i := 0; i < beatmap.to_be_freed.len; i++ {
		beatmap.to_be_freed[i].free()
		beatmap.to_be_freed = beatmap.to_be_freed[1..]
		i--
	}
}

pub fn (mut beatmap Beatmap) draw() {
	// FIXME: This is kinda fucked ngl
	// FIXME: data race or smth idk what its called
	beatmap.storyboard.mutex.@lock()

	// Background/Storyboard draws
	gfx.begin_pass(sapp.create_default_pass(graphic.global_renderer.pass_action))

	beatmap.storyboard.draw() // Includes background

	// Shitty background dim
	beatmap.ctx.draw_rect_filled(0, 0, int(settings.global.window.width), int(settings.global.window.height),
		gx.Color{0, 0, 0, u8(settings.global.gameplay.playfield.background.background_dim)})

	// Playfield
	// Insides
	beatmap.ctx.draw_rect_filled(f32((int(settings.global.window.width) - beatmap.playfield_size.x - (beatmap.difficulty.circle_radius * x.resolution.playfield_scale)) / 2),
		f32((int(settings.global.window.height) - beatmap.playfield_size.y - (beatmap.difficulty.circle_radius * x.resolution.playfield_scale)) / 2),
		f32(beatmap.playfield_size.x +
		(beatmap.difficulty.circle_radius * x.resolution.playfield_scale)), f32(
		beatmap.playfield_size.y + (beatmap.difficulty.circle_radius * x.resolution.playfield_scale)),
		gx.Color{0, 0, 0, 150})

	// Outline
	beatmap.ctx.draw_rect_empty(f32((int(settings.global.window.width) - beatmap.playfield_size.x - (beatmap.difficulty.circle_radius * x.resolution.playfield_scale)) / 2),
		f32((int(settings.global.window.height) - beatmap.playfield_size.y - (beatmap.difficulty.circle_radius * x.resolution.playfield_scale)) / 2),
		f32(beatmap.playfield_size.x +
		(beatmap.difficulty.circle_radius * x.resolution.playfield_scale)), f32(
		beatmap.playfield_size.y + (beatmap.difficulty.circle_radius * x.resolution.playfield_scale)),
		gx.white)

	// Done
	sgl.draw()
	gfx.end_pass()
	gfx.commit()

	// Draw stuff on its own "layer" or whatever it was called in
	// sokol.
	if !settings.global.gameplay.hitobjects.disable_hitobjects { // We might want hitcircle hitsounds but not the hitcircle itself, so on draw calls ignored it but not on update calls
		for i := beatmap.queue.len - 1; i >= 0; i-- {
			mut hitobject := &beatmap.queue[i]

			// Render slider body
			// TODO: Fix this maybe, it looks kinda ugly like this.
			if mut hitobject is object.Slider {
				if beatmap.last_update <= hitobject.get_start_time() - beatmap.difficulty.preempt
					|| beatmap.last_update <= hitobject.get_end_time() + difficulty.hit_fade_out {
					// local_position := x.resolution.camera.translate(hitobject.position)
					hitobject.slider_renderer_attr.draw_slider(1.0 - hitobject.slider_renderer_fade.value,
						hitobject.color)
					// beatmap.ctx.draw_text(int(local_position.x), int(local_position.y), "Type: ${hitobject.typ} | Pixel length: ${hitobject.pixel_length}", gx.TextCfg{color: gx.Color{255, 255, 255, u8(hitobject.slider_renderer_fade.value * 255.0)}, align: .center})
					// beatmap.ctx.draw_text(int(local_position.x), int(local_position.y) + 16, "Curve length: ${hitobject.curve.length} | Curve lines: ${hitobject.curve.lines.len}", gx.TextCfg{color: gx.Color{255, 255, 255, u8(hitobject.slider_renderer_fade.value * 255.0)} align: .center})
				}
			}

			// Render hitcircle
			gfx.begin_pass(sapp.create_default_pass(graphic.global_renderer.pass_action))
			beatmap.queue[i].draw(
				ctx: beatmap.ctx
				time: beatmap.last_update
				scale: beatmap.last_boost
				camera: x.resolution.camera
			)
			sgl.draw()
			gfx.end_pass()
			gfx.commit()
		}
	}

	// Free slider
	// beatmap.free_slider_attr()

	//
	beatmap.storyboard.mutex.unlock()
}

// Property
pub fn (beatmap &Beatmap) get_audio_path() string {
	return os.join_path(beatmap.root, beatmap.general.audio_filename)
}

pub fn (beatmap &Beatmap) get_bg_path() string {
	return os.join_path(beatmap.root, beatmap.general.bg_filename)
}

pub fn (beatmap &Beatmap) get_video_path() string {
	return os.join_path(beatmap.root, beatmap.general.video_filename)
}

pub fn (beatmap &Beatmap) get_sb_path() string {
	// TODO: per-difficulty sb
	if files := os.glob(os.join_path(beatmap.root, '*.osb')) {
		return files[0] or { '' }
	}

	return ''
}
