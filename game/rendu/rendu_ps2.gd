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
	env.background_color = reglages.ciel()

	# Sans ambiante, tout ce qui n'est pas sous un lampadaire est un aplat
	# parfaitement noir — illisible, et ce n'est pas ce que faisait la PS2.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = reglages.brume()
	env.ambient_light_energy = reglages.lumiere_ambiante()

	# Le brouillard n'est pas un effet d'ambiance : c'est ce qui masque la
	# limite d'affichage. Meme role que dans GTA III. De jour il change de
	# nature sans changer de fonction : une brume de chaleur qui BLANCHIT le
	# lointain au lieu de l'assombrir.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = reglages.brume()
	env.fog_light_energy = 1.0
	env.fog_depth_begin = reglages.brume_debut()
	env.fog_depth_end = reglages.brume_fin()
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = reglages.brume_ciel()

	_configurer_soleil()

	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false


# Le soleil se leve et se couche.
#
# Il EXISTE a toute heure maintenant, alors qu'une version anterieure le
# supprimait la nuit. La difference compte : un noeud detruit puis recree a
# chaque bascule ne peut pas s'animer, et l'aube n'aurait ete qu'un
# interrupteur.
#
# De nuit il reste, energie nulle et sous l'horizon, ce qui ne coute presque
# rien pour une seule source directionnelle — et tout vient alors des
# lampadaires, des phares et des fenetres allumees.
func _configurer_soleil() -> void:
	var scene := scene_3d()
	var soleil := scene.get_node_or_null("Soleil") as DirectionalLight3D
	if soleil == null:
		soleil = DirectionalLight3D.new()
		soleil.name = "Soleil"
		scene.add_child(soleil)

	var nuit := Reglages.nuit_part()
	var jour := 1.0 - nuit

	# La hauteur suit une arche : rasante au lever et au coucher, haute a midi.
	# On la calcule sur la meme part de jour que le reste, plutot que sur
	# l'heure : les deux resteront d'accord si on change la duree de l'aube.
	var hauteur := lerpf(-8.0, reglages.soleil_hauteur, jour)
	# Il tourne dans le ciel au fil de la journee, sinon les ombres pointent
	# toute la journee dans la meme direction et midi ressemble a huit heures.
	var azimut: float = reglages.soleil_azimut + (Reglages.heure - 13.0) * 12.0

	soleil.rotation_degrees = Vector3(-hauteur, azimut, 0.0)
	soleil.light_energy = reglages.soleil_energie * jour
	# Rasant, il rougit. C'est ce qui fait lire une heure plutot qu'une autre.
	soleil.light_color = reglages.soleil_couleur.lerp(
			Color(1.0, 0.58, 0.34), clampf(nuit * 1.4, 0.0, 1.0))
	# Une lumiere d'energie nulle projette quand meme ses ombres : on les coupe,
	# et on economise la carte d'ombres pendant toute la nuit.
	soleil.shadow_enabled = reglages.soleil_ombres and jour > 0.05
	soleil.visible = jour > 0.01


## La camera active du monde. Les autres systemes passent par ici plutot que
## de fouiller l'arbre, pour que la structure du viewport reste un detail.
func camera() -> Camera3D:
	return _viewport.get_camera_3d()


## Le noeud sous lequel tout le contenu 3D doit etre ajoute.
func scene_3d() -> Node3D:
	return $Rendu/Scene3D
