<div style="float: right; text-align: center;">
    <div>
        <a href="https://youtu.be/2b1IexhKPz4" title="Image is courtesy of Iyowa.">
            <img width="200" align="right" style="float: right; margin: 0 10px 0 0;" alt="Kurarin" src="assets/common/textures/kurarin.png">
        </a>
    </div>
</div>

## Disclaimer

This program is far from finished and it's not exactly stable either but it works most of the time. <br/>
Use [danser-go](https://github.com/Wieku/danser-go) or [McOsu](https://github.com/McKay42/McOsu), if you're looking for a client alternative.

## Preview
[Click here for more video preview(s)](PREVIEWS.md)

https://github.com/xjunko/kurarin/assets/44401509/c834fcd4-43b3-4abc-bc6a-967446b2ed77

## Releases
You can get the latest development build from the CI/CD
[here](https://github.com/xjunko/kurarin/releases/tag/latest).

## Running

```bash
./kurarin [...arguments]
```

## Settings

The program will create a `settings.json` file on startup for the first time, and exit right after. <br/>
The next startup will be normal.

## Features

Currently supports:

- Gameplay
- Auto (+ cursordance)
- Rendering (Requires [FFmpeg](https://ffmpeg.org/) to be installed in `$PATH`)
- Storyboard
- Replay (`.osr`) support

Currently does not support:

- Stupid/Aspire maps, the program will either OOM your system or straight up crash, beware.

## Building

### Requirements

- V
- GCC/Clang
- OpenGL 3

#### Linux

Tested with Arch but it _should_ work anywhere else as long as it's linux.

Use [`ext/build.sh`](https://github.com/FireRedz/kurarin/blob/rewrite/ext/build.sh) to build the program, no makefile :).

## Credits

Some of the code is _derived_ or literally copy-pasted from these projects, so big credits to them.

- [danser-go](https://github.com/Wieku/danser-go) by [Wieku](https://github.com/Wieku)
- [McOsu](https://github.com/McKay42/McOsu) by [McKay](https://github.com/McKay42)
- [osr2mp4](https://github.com/uyitroa/osr2mp4-core) by [yuitora](https://github.com/uyitroa)
- [opsu-dance](https://github.com/yugecin/opsu-dance) by [yugecin](https://github.com/yugecin)
