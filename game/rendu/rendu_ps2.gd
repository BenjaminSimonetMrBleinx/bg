# Pipeline de rendu PS2.
#
# Tout le 3D est rendu dans un SubViewport a resolution reduite (512x288 par
# defaut), puis agrandi en plein ecran avec un filtrage lineaire. C'est ce
# double mouvement qui produit le rendu d'epoque : la geometrie est nette au
# moment du rendu, et le flou vient de l'agrandissement, exactement comme une
# PS2 sur un ecran moderne.
#
# Ce script ne contient aucun nombre : tout vient de reglages.tres.
extends Node

@export var reglages: Reglages

@onready var _viewport: SubViewport = $Rendu
@onready var _ecran: TextureRect = $Affichage/Ecran
@onready var _environnement: WorldEnvironment = $Rendu/Environnement


func _ready() -> void:
	if reglages == null:
		push_error("rendu_ps2 : aucune ressource Reglages assignee")
		return
	appliquer()


## Relit reglages.tres et reconfigure tout. Appelable a chaud : c'est ce qui
## permet de bouger un curseur et de voir le resultat sans relancer.
func appliquer() -> void:
	_configurer_viewport()
	_configurer_ecran()
	_configurer_environnement()


func _configurer_viewport() -> void:
	_viewport.size = Vector2i(reglages.largeur_rendu, reglages.hauteur_rendu)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Aucun anti-aliasing : il lisserait la geometrie avant l'agrandissement,
	# et on perdrait le cachet basse resolution.
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_hdr_2d = false
	_viewport.positional_shadow_atlas_size = 1024

	# Indispensable, et desactive par defaut : sans ecouteur audio 3D, TOUT
	# son positionne place dans ce viewport est muet. La camera devient
	# l'oreille. Les lecteurs non positionnes (ambiance, musique) sortent
	# quand meme, ce qui rend la panne particulierement trompeuse : on entend
	# la rue, on n'entend jamais le moteur.
	_viewport.audio_listener_enable_3d = true


func _configurer_ecran() -> void:
	# Lineaire = flou PS2. Nearest = texels carres PS1. Le curseur est dans
	# reglages.tres parce que c'est exactement le genre de chose qu'on veut
	# pouvoir comparer en une seconde.
	_ecran.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR if reglages.filtrage_lineaire
		else CanvasItem.TEXTURE_FILTER_NEAREST
	)
	_ecran.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ecran.stretch_mode = TextureRect.STRETCH_SCALE


func _configurer_environnement() -> void:
	var env := _environnement.environment
	if env == null:
		env = Environment.new()
		_environnement.environment = env

	env.background_mode = Environment.BG_COLOR
	env.background_color = reglages.ciel_couleur

	# Sans ambiante, tout ce qui n'est pas sous un lampadaire est un aplat
	# parfaitement noir — illisible, et ce n'est pas ce que faisait la PS2.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = reglages.brouillard_couleur
	env.ambient_light_energy = reglages.ambiante

	# Le brouillard n'est pas un effet d'ambiance : c'est ce qui masque la
	# limite d'affichage. Meme role que dans GTA III.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = reglages.brouillard_couleur
	env.fog_light_energy = 1.0
	env.fog_depth_begin = reglages.brouillard_debut
	env.fog_depth_end = reglages.brouillard_fin
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 1.0

	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false


## La camera active du monde. Les autres systemes passent par ici plutot que
## de fouiller l'arbre, pour que la structure du viewport reste un detail.
func camera() -> Camera3D:
	return _viewport.get_camera_3d()


## Le noeud sous lequel tout le contenu 3D doit etre ajoute.
func scene_3d() -> Node3D:
	return $Rendu/Scene3D
