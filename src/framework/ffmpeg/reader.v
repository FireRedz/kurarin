module ffmpeg

import os
import math
import framework.logging
// import core.common.settings

pub struct FFmpegReader {
mut:
	video_path        string
	target_resolution [2]f64

	process &os.Process = unsafe { nil }
	ok      bool
pub mut:
	buffer []u8
	// Info
	metadata &Metadata = unsafe { nil }
}

pub fn (mut reader FFmpegReader) initialize_video_data() {
	if !os.exists(reader.video_path) {
		logging.error('Tried to read unexisting video file.')
	}
}

pub fn (mut reader FFmpegReader) initialize_ffmpeg() {
	reader.process = os.new_process(os.find_abs_path_of_executable('ffmpeg') or { panic(err) })

	ffmpeg_arg := [
		'-i',
		reader.video_path,
		'-f',
		'rawvideo',
		'-pix_fmt',
		'rgba',
		'-ss',
		'0:0:0',
		'-vf',
		'scale=${reader.metadata.width}:${reader.metadata.height}',
		'-',
	]

	reader.process.set_args(ffmpeg_arg)
	reader.process.set_redirect_stdio()
	reader.process.run()
	reader.ok = true
}

pub fn (mut reader FFmpegReader) update() {
	if !reader.ok {
		return
	}

	expected_data_length := int(reader.metadata.width * reader.metadata.height * 4)
	mut remaining := expected_data_length
	mut last_data_length := 0

	unsafe {
		reader.buffer.clear()

		// TODO: I dont like this, streaming the buffer is kinda bad tbh
		for reader.buffer.len < expected_data_length {
			data, amount_of_bytes := os.fd_read(reader.process.stdio_fd[1], math.min(remaining,
				4096 * 6))
			remaining -= amount_of_bytes
			reader.buffer << data.bytes()
			data.free()

			// Check if we dont have any new data received
			if remaining == last_data_length {
				// Ok shit, prolly something fucked up or video finished
				logging.error('Invalid video data, stopping video.')
				reader.ok = false // This video is invalid now, stop everything.
				reader.stop()
				break
			}
			last_data_length = remaining
		}
	}
}

pub fn (mut reader FFmpegReader) stop() {
	// Dont block
	spawn fn (mut reader FFmpegReader) {
		reader.ok = false

		reader.process.close()
		for reader.process.status == .running {}
		logging.info('Video stopped!')
	}(mut reader)
}

pub fn load_video(path string) &FFmpegReader {
	mut reader := &FFmpegReader{
		video_path: path
	}
	reader.metadata = load_metadata(path)

	logging.info('Loaded video: ${path}')

	return reader
}
