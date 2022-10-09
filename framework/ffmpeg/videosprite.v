
module ffmpeg

import sync
import library.gg

import framework.math.time
import framework.math.vector
import framework.graphic.sprite

import core.osu.x
import core.common.settings

pub struct VideoSprite {
	sprite.Sprite

	pub mut:
		source      &FFmpegReader = voidptr(0)
		tex_id      int
		last_time   f64
		delta_count f64
		frametime   f64
		videotime   f64
		start_at    f64 = -1889
		ctx         &gg.Context = voidptr(0)
		need_update bool
		mutex       &sync.Mutex = sync.new_mutex()
}

pub fn (mut video VideoSprite) draw(arg sprite.CommonSpriteArgument) {
	video.mutex.@lock()
	if video.need_update {
		video.update_texture()
		video.need_update = false
	}
	video.mutex.unlock()


	if video.is_drawable_at(arg.time) || video.always_visible {
		video.ctx.draw_image_with_config(gg.DrawImageConfig{
			img_id: video.tex_id,
			img_rect: gg.Rect{
				x: f32((x.resolution.resolution.x - (video.size.x * arg.scale)) / 2.0),
				y: f32((x.resolution.resolution.y - (video.size.y * arg.scale)) / 2.0),
				width: f32(video.size.x * arg.scale),
				height: f32(video.size.y * arg.scale)
			},
			color: video.color,
			additive: video.additive
		})
	}

}

pub fn (mut video VideoSprite) update_video() {
	video.source.update()
}

pub fn (mut video VideoSprite) update_texture() {
	video.ctx.update_pixel_data(video.tex_id, video.source.buffer.data)
}

pub fn (mut video VideoSprite) update(time f64) {
	video.Sprite.update(time)

	if time <= video.start_at {
		return
	}

	// // Update video frame when needed...
	// video.mutex.@lock()
	// delta := time - video.last_time
	// video.last_time = time

	// video.delta_count += delta
	// for video.delta_count >= video.frametime {
	// 	video.delta_count -= video.frametime
	// 	video.need_update = true
	// 	video.update_video()
	// }
	// video.mutex.unlock()

	video.mutex.@lock()
	for video.videotime <= time {
		video.videotime += video.frametime
		video.update_video()
		video.need_update = true
	}
	video.mutex.unlock()
}

pub fn make_video_sprite(path string, mut ctx &gg.Context, offset f64) &VideoSprite {
	mut video := &VideoSprite{ctx: ctx, always_visible: true}

	// Load video
	video.source = load_video(path)

	// start ffmpeg
	video.source.initialize_video_data()
	video.source.initialize_ffmpeg()

	// Make a texture for it
	video.tex_id = ctx.new_streaming_image(int(video.source.metadata.width), int(video.source.metadata.height), 4, gg.StreamingImageConfig{})

	// ehh
	video.frametime = 1000.0 / video.source.metadata.fps
	video.videotime += video.frametime
	video.update_video() // Force first frame

	// fade in
	video.add_transform(typ: .fade, time: time.Time{0, 1000}, before: [0.0], after: [255.0])

	// Resize the video with gpu (or cpu idk)
	ratio := settings.global.window.width / video.source.metadata.width

	video.reset_size_based_on_texture(
		size: vector.Vector2{x: video.source.metadata.width * ratio, y: video.source.metadata.height * ratio}
	)
	video.reset_attributes_based_on_transforms()

	// Seek to offset
	for i := video.videotime; i < offset; i += video.frametime {
		video.update_video()
	}

	return video
}