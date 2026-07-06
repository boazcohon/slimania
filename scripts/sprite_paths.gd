extends Node
## ============================================================================
##  SpritePaths  (autoload singleton — available everywhere as "SpritePaths")
## ----------------------------------------------------------------------------
##  The ONE place in the whole game that knows where Isaac's PNG files live.
##  Every other script asks for art by a short nickname, like:
##
##      my_sprite.texture = SpritePaths.tex("goopzz")
##
##  So when Isaac adds or renames art, update THIS file and nothing else.
##  If a file is missing, the game still runs — you just get a gray box and a
##  warning in the Output panel instead of a crash.
## ============================================================================

const PATHS: Dictionary = {
	# --- Characters ---------------------------------------------------------
	# Goopzz v2 (the shiny shaded ones, 1024px). The old "full rez 2d" files
	# are still in the folder if you ever want to compare.
	"goopzz": "res://slimania assets/characters/goopzz/goopzz.png",
	"goopzz_angry": "res://slimania assets/characters/goopzz/goopzz angry.png",
	"enemy_slime": "res://slimania assets/characters/enemy slime/enemy slime full rez 2d.png",
	"enemy_slime_attacking": "res://slimania assets/characters/enemy slime/enemy slime attacking full rez 2d.png",
	"kath": "res://slimania assets/characters/catherine/cath full rez 2d.png",  # Phase 2 story NPC (not used yet)
	"help_slime": "res://slimania assets/characters/help slime/help slime full rez 2d.png",  # Phase 2 ally (not used yet)

	# --- Items ----------------------------------------------------------------
	"sword": "res://slimania assets/items/goopzz/sword/goopzz s word.png",
	"move_disc": "res://slimania assets/items/move disc/move disc.png",

	# --- Terrain ---------------------------------------------------------------
	# The sand art has a black band along the top — we use that as the visible
	# "top wall" of each room, Among-Us style. The forest ground has no band,
	# so overworld.gd paints a dark top wall for forest rooms itself.
	"beach_sand": "res://slimania assets/terrain/areas/beach/beach sand normal full rez 2d.png",
	"beach_scene": "res://slimania assets/terrain/areas/beach/ground.png",
	"forest_ground": "res://slimania assets/terrain/areas/forest/forest grassy ground.png",
	"forest_town_ground": "res://slimania assets/terrain/areas/forest/forest town.png",

	# --- Logos ------------------------------------------------------------------
	"logo": "res://slimania assets/logo/slimania logo.png",
	"skybox": "res://slimania assets/logo/2 textures/skybox.png",
}


## Look up a texture by nickname. Never crashes: missing art returns a gray
## placeholder box so the game keeps running.
func tex(nickname: String) -> Texture2D:
	if PATHS.has(nickname) and ResourceLoader.exists(PATHS[nickname]):
		return load(PATHS[nickname])
	push_warning("SpritePaths: no art found for '%s' — using a gray placeholder box." % nickname)
	var placeholder := PlaceholderTexture2D.new()
	placeholder.size = Vector2(64, 64)
	return placeholder
