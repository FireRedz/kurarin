module settings

import gg

pub struct Gameplay {
pub mut:
	paths      Path
	playfield  Playfield
	input      Input
	skin       Skin
	hitobjects HitObjects
	overlay    Overlay
}

pub struct Path {
pub mut:
	beatmaps string
	skins    string
	replays  string
}

pub struct Playfield {
pub mut:
	objects_visible bool
	lead_in_time    f64

	background Background
}

pub struct Background {
pub mut:
	enable_storyboard bool
	enable_video      bool
	background_dim    int
}

pub struct Input {
pub mut:
	left_key  gg.KeyCode
	right_key gg.KeyCode
}

pub struct Skin {
pub mut:
	current_skin         string
	use_colors_from_skin bool
	use_beatmap_colors   bool
	cursor               Cursor
}

pub struct Cursor {
pub mut:
	style        f64
	size         f64
	trail_size   f64
	trail_length f64
	visible      bool
}

pub struct HitObjects {
pub mut:
	disable_hitobjects bool

	scale_to_beat bool
	// Slider customization stuff
	slider_width                 f64
	slider_lazer_style           bool
	slider_body_use_border_color bool // im so fucking bad at naming shit
	// dumbass shit
	rainbow_hitcircle bool
	rainbow_slider    bool
}

pub struct Overlay {
pub mut:
	info       bool // Score, Combo
	visualizer bool
}

// Factory
pub fn make_gameplay_settings() Gameplay {
	mut gameplay_ := Gameplay{
		paths: Path{
			beatmaps: '<Path to your osu! beatmaps folder here>'
			skins: '<Path to your osu! skins folder here>'
		}
		playfield: Playfield{
			objects_visible: true
			lead_in_time: 3.0
			background: Background{
				enable_storyboard: true
				enable_video: true
				background_dim: 100
			}
		}
		input: Input{
			left_key: .a
			right_key: .s
		}
		skin: Skin{
			current_skin: ''
			use_colors_from_skin: true
			use_beatmap_colors: false
			cursor: Cursor{
				style: 2
				size: 0.75
				trail_size: 1.0
				trail_length: 1.0
				visible: true
			}
		}
		hitobjects: HitObjects{
			disable_hitobjects: false
			scale_to_beat: false
			rainbow_hitcircle: false
			rainbow_slider: false
			slider_width: 1.0
			slider_lazer_style: false
			slider_body_use_border_color: false
		}
		overlay: Overlay{
			visualizer: true
			info: true
		}
	}

	$if release_unique ? {
		gameplay_.paths.beatmaps = 'assets/osu/maps'
		gameplay_.paths.skins = 'assets/osu/skins'
		gameplay_.skin.current_skin = 'default'
	}

	return gameplay_
}
