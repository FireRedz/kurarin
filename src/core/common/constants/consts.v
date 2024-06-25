module constants

import v.vmod

pub const game_manifest = vmod.decode(@VMOD_FILE) or { panic(err) }
pub const game_name = game_manifest.name
pub const game_version = game_manifest.version
