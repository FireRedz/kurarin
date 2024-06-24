module export

import os
import time as timelib
import framework.audio
import core.common.settings

const used_import = 1

pub struct Video {
pub mut:
	video_proc  &os.Process = unsafe { 0 }
	record_data &u8 = unsafe { 0 }

	audio_proc &os.Process = unsafe { 0 }
	audio_data []u8
}

// window_init and window_draw but for recording
pub fn (mut video Video) init_video_pipe_process() {
	video.video_proc = os.new_process(os.find_abs_path_of_executable('ffmpeg') or { panic(err) })

	// vfmt off
	mut ffmpeg_arg := [
		'-y',

		'-f', 'rawvideo',
		'-vcodec', 'rawvideo',
		'-s', '${int(settings.global.window.width)}x${int(settings.global.window.height)}',
		'-pix_fmt', 'rgba',
		'-r', settings.global.video.fps.str(),
		'-i', '-',

		"-an"

		'-vf', 'vflip',
		'-c:v', 'h264_nvenc',
		'-color_range', '1',
		'-colorspace', '1',
		'-color_trc', '1',
		'-color_primaries', '1',
		'-movflags', '+write_colr',
		'-hide_banner',
		// '-loglevel', 'panic',
	]

	ffmpeg_arg << [
		'-pix_fmt', 'yuv420p',
		"-rc", "vbr",
		"-b:v", "400M",
		"-cq", "23",
		"-profile", "high", 
		"-preset", "p3"
	]

	ffmpeg_arg << [
		'temp.mp4', // output
	]

	// vfmt on

	video.video_proc.set_args(ffmpeg_arg)
	video.video_proc.set_redirect_stdio()
	video.video_proc.run()

	// Init record buffer
	img_size := int(settings.global.window.width) * int(settings.global.window.height) * 4
	video.record_data = unsafe { &u8(malloc(img_size)) }

	println('VideoPipe Process started!')
}

pub fn (mut video Video) init_audio_pipe_process() {
	audio_buffer_size := unsafe { audio.boxed_backend.backend.get_required_buffer_size_for_mixer(1.0 / settings.global.video.update_fps) } // Render Update FPS (Refer to window_draw_recording in main)
	video.audio_data = []u8{len: audio_buffer_size}

	// Create the process
	video.audio_proc = os.new_process(os.find_abs_path_of_executable('ffmpeg') or { panic(err) })

	ffmpeg_arg := [
		'-y',
		'-f',
		'f32le',
		'-acodec',
		'pcm_f32le',
		'-ar',
		'48000',
		'-ac',
		'2',
		'-i',
		'-',
		'-nostats',
		'-vn',
		'-nostdin', // shut the fuck upp ffmpeg
		'temp.mp3',
	]

	video.audio_proc.set_args(ffmpeg_arg)
	video.audio_proc.set_redirect_stdio()
	video.audio_proc.run()

	println('AudioPipe Process started!')
}

pub fn (mut video Video) close_pipe_process() {
	video.video_proc.close()
	video.audio_proc.close()

	// Wait till the process done
	for video.video_proc.status == .running {}
	for video.audio_proc.status == .running {}
	timelib.sleep(5 * timelib.second) // Wait for a few second just to make sure

	// Merge audio (for now we'll do it over here instead of doing it on pipe)
	audio_path := 'temp.mp3'
	result := os.execute('ffmpeg -i temp.mp4 -i "${audio_path}" -map 0:0 -map 1:0 -c:v copy -preset ultrafast -async 1 "output.mp4" -y')
	println(result)
}

pub fn (mut video Video) pipe_window() {
	// read gl buffer
	C.v_sapp_gl_read_rgba_pixels(0, 0, int(settings.global.window.width), int(settings.global.window.height),
		video.record_data)

	// This might not be worth it after all.
	unsafe {
		img_size := int(settings.global.window.width) * int(settings.global.window.height) * 4
		mut remaining := img_size

		for remaining > 0 {
			written := C.write(video.video_proc.stdio_fd[0], video.record_data, remaining)

			if written < 0 {
				return
			}

			remaining = remaining - written

			video.record_data = voidptr(video.record_data + written)
		}

		free(video.record_data)

		video.record_data = &u8(malloc(img_size))
	}
}

pub fn (mut video Video) pipe_audio() {
	unsafe {
		audio.boxed_backend.backend.get_mixer_data(mut video.audio_data)
	}

	// hacky
	unsafe {
		temp := video.audio_data.bytestr()
		video.audio_proc.stdin_write(temp)
		temp.free()
	}
}
