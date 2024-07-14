module elzma

import dl

type DecompressAlloc = fn () voidptr

type DecompressRun = fn (voidptr, voidptr, voidptr, voidptr, voidptr, int) int

type DecompressFree = fn (voidptr)

fn C.fmemopen(&voidptr, usize, &u8) &C.FILE

fn get_elzma_dl() !&voidptr {
	return dl.open_opt('${@VMODROOT}/DLLs/libeasylzma.so', dl.rtld_lazy)!
}

fn read_func(mut ctx []u8, buf &voidptr, size &usize) int {
	unsafe {
		file := C.fmemopen(ctx#[..*size].data, *size, 'rb'.str)

		if file == C.NULL {
			panic('[ELZMA] Failed to open memory for reading file.')
		}

		*size = C.fread(buf, 1, ctx.len, file)

		if *size > ctx.len {
			*ctx = ctx[ctx.len..]
		} else {
			*ctx = ctx[*size..]
		}
	}
	return 0
}

fn write_func(mut ctx []string, buf voidptr, size u32) usize {
	ctx << unsafe { cstring_to_vstring(buf) }
	return size
}

pub fn decode_lzma(data []u8) !string {
	if elzma_dl := get_elzma_dl() {
		// Function(s)
		decompress_alloc := DecompressAlloc(dl.sym_opt(elzma_dl, 'elzma_decompress_alloc')!)
		decompress_run := DecompressRun(dl.sym_opt(elzma_dl, 'elzma_decompress_run')!)
		decompress_free := DecompressFree(dl.sym_opt(elzma_dl, 'elzma_decompress_free')!)

		// Start
		hand := decompress_alloc()

		if hand == C.NULL {
			panic('Couldnt allocated decompression object.')
		}

		mut output_buffer := []string{}

		r := decompress_run(hand, read_func, data, write_func, output_buffer, 1)

		if r != 0 {
			panic('Failed to read replay file. | Error code: ${r}')
		}

		final := output_buffer.join('').clone()

		unsafe {
			output_buffer.free()
			decompress_free(&hand)
		}
		return final
	}

	panic('[ELZMA] Failed to load libeasylzma.so.0.0.8. [Linux]')

	return ''
}
