# Pipeline de rendu PS2.
#
# Tout le 3D est rendu dans un SubViewport a resolution reduite (960x720 par
# defaut), puis agrandi en plein ecran avec un filtrage lineaire. C'est ce
# double mouvement qui produit le rendu d'epoque : la geometrie est nette au
# moment du rendu, et le flou vient de l'agrandissement, exactement comme une
# PS2 sur un ecran moderne.
#
# CE QUI FAIT LE GRAIN, C'EST LE RAPPORT, PAS LA FINESSE. La fenetre est a
# 1440x1080 dans project.godot ; l'agrandissement vaut donc 1,5. On est reste
# longtemps a 512x384 dans 1024x768, soit un facteur 2 — c'etait plus grossier,
# mais surtout tout detail sous deux pixels disparaissait, et aucun travail sur
# la matiere ne se voyait. Monter la resolution SANS monter la fenetre aurait
# rendu un facteur 1,07, c'est-a-dire un jeu net comme les autres.
#
# Ce script ne contient aucun nombre : tout vient de reglages.tres.
extends Node

@export var reglages: Reglages

@onready var _viewport: SubViewport = $Rendu
@onready var _ecran: TextureRect = $Affichage/Ecran
@onready var _environnement: WorldEnvironment = $Rendu/Environnement
@onready var _echelle: Control = $Rendu/Interface/Echelle


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
	_configurer_interface()
	_configurer_environnement()


func _configurer_viewport() -> void:
	_viewport.size = Vector2i(reglages.largeur_rendu, reglages.hauteur_rendu)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Aucun anti-aliasing : il lisserait la geometrie avant l'agrandissement,
	# et on perdrait le cachet basse resolution.
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_hdr_2d = false

	# LA CARTE D'OMBRES, ET SON DECOUPAGE.
	#
	# Le defaut de Godot donne au premier quadrant une seule case — un quart de
	# la carte pour UNE lumiere. Avec huit lampadaires, deux phares et les
	# lampes d'interieur, c'est du gachis : la source la plus proche prend tout
	# et les autres se battent pour le reste.
	#
	# On decoupe donc en deux quadrants de quatre cases pour ce qui est pres —
	# les phares, la lampe qu'on longe — et deux de seize pour le fond, ou une
	# ombre de 256 pixels est deja plus fine que ce que le brouillard laisse
	# voir.
	_viewport.positional_shadow_atlas_size = reglages.atlas_ombres
	_viewport.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	_viewport.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	_viewport.positional_shadow_atlas_quad_2 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16
	_viewport.positional_shadow_atlas_quad_3 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16

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


# L'INTERFACE EST DESSINEE PETIT, PUIS AGRANDIE.
#
# Le HUD partage le viewport de la 3D — c'est voulu, les HUD PS2 partageaient le
# meme tampon, et la capture le photographie avec la scene. Mais tout y est
# ecrit en pixels absolus : une police de 13, une barre de vie de 78 pixels, un
# rayon de roue de 92 pris dans reglages.tres. Ces nombres ont ete regles a
# l'oeil sur un rendu de 512x384.
#
# Monter la resolution sans rien faire d'autre ne rend donc pas l'interface plus
# fine : elle la rend plus PETITE, de tout le facteur d'agrandissement. Un texte
# qui occupait 3,4 % de la hauteur d'ecran tombait a 1,8 %.
#
# On la dessine dans les cotes de reference et on applique le facteur ici. Tout
# ce qui lit size continue de lire 512x384, et aucun des six scripts d'interface
# n'a eu a bouger.
func _configurer_interface() -> void:
	if _echelle == null:
		return
	# Par les offsets et non par size : ecrire size sur un Control dont les
	# ancres opposees different fait ecrire un avertissement sur la sortie
	# d'erreur, et une seule ligne de stderr fait echouer bg.ps1 capture.
	var repere := reglages.taille_de_reference()
	_echelle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_echelle.offset_left = 0.0
	_echelle.offset_top = 0.0
	_echelle.offset_right = repere.x
	_echelle.offset_bottom = repere.y
	var f := reglages.facteur_hud()
	_echelle.scale = Vector2(f, f)


func _configurer_environnement() -> void:
	var env := _environnement.environment
	if env == null:
		env = Environment.new()
		_environnement.environment = env

	# UN CIEL, PAS UN APLAT. De nuit, le fond uni ne donnait rien au-dessus des
	# toits : pas un repere quand on leve la camera, et aucune source visible
	# pour justifier qu'on y voie quelque chose. Voir rendu/ciel_nuit.gdshader.
	env.background_mode = Environment.BG_SKY
	env.background_color = reglages.ciel()
	_configurer_ciel(env)

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

	# L'AIR QUI SE VOIT, PAR-DESSUS le brouillard de profondeur.
	#
	# Les deux coexistent et ce n'est pas un doublon : celui du dessus masque la
	# limite d'affichage — c'est lui qui rend la ville finie — pendant que
	# celui-ci ne travaille que sur les premiers metres, pour donner un CONE aux
	# lampadaires au lieu d'une flaque au sol.
	#
	# S'ils se cumulent mal, c'est TOUJOURS le volumetrique qu'on baisse : sans
	# le brouillard de profondeur, on voit le bord du monde.
	env.volumetric_fog_enabled = reglages.brume_volume
	if reglages.brume_volume:
		env.volumetric_fog_density = reglages.brume_volume_densite()
		env.volumetric_fog_length = reglages.brume_volume_portee
		env.volumetric_fog_anisotropy = reglages.brume_volume_diffusion
		env.volumetric_fog_albedo = reglages.brume()
		env.volumetric_fog_detail_spread = 2.0

	_configurer_soleil()

	_configurer_post_traitement(env)


# CE QUI SE PASSE APRES QUE LA SCENE EST RENDUE.
#
# Tout etait coupe ici, et ce n'etait pas un oubli : a 512x384 la plupart de
# ces effets ne se voyaient pas, ou se voyaient trop. A 960x720 ils tiennent, et
# le releve de cout laisse toute la marge — 0,6 ms par image sur les 33
# disponibles.
#
# Chacun est pilote par un booleen de reglages.tres, ce qui n'est pas du luxe :
# ces trois-la ne se jugent pas ensemble. On en bascule un, on capture, on
# compare. Les allumer tous d'un coup et trouver l'image moins bonne ne dit pas
# lequel est en cause.
func _configurer_post_traitement(env: Environment) -> void:
	# LE TONEMAP CHANGE TOUTES LES COULEURS DU JEU D'UN COUP.
	#
	# Lineaire coupait net a 1.0 : un lampadaire, un phare et une fenetre
	# allumee rendaient la meme tache blanche, sans forme. Filmique garde de la
	# matiere au-dela et creuse un peu les tons moyens — d'ou l'exposition, qui
	# rend ce qu'il a pris.
	env.tonemap_mode = (
		Environment.TONE_MAPPER_FILMIC if reglages.tonemap_filmique
		else Environment.TONE_MAPPER_LINEAR
	)
	env.tonemap_exposure = reglages.exposition()
	env.tonemap_white = reglages.blanc

	env.glow_enabled = reglages.glow
	if reglages.glow:
		# ECRAN plutot qu'ADDITIF : l'additif empile les halos et deux
		# lampadaires proches deviennent une seule flaque blanche.
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		env.glow_intensity = reglages.glow_intensite()
		env.glow_strength = 1.0
		env.glow_bloom = reglages.glow_bloom
		env.glow_hdr_threshold = reglages.glow_seuil()
		env.glow_hdr_scale = 2.0
		# LES NIVEAUX SONT UN CHOIX, PAS UN DEFAUT.
		#
		# Le 1 fait un halo d'un pixel qui scintille des que la camera bouge —
		# a cette resolution il attrape le bruit plutot que les sources. Les 5 a
		# 7 etalent si large qu'ils ne font plus une aureole mais un voile sur
		# toute l'image : c'est du brouillard, et on en a deja un qui fait ce
		# travail mieux. Restent 2, 3 et 4.
		#
		# ATTENTION A LA NUMEROTATION : l'inspecteur affiche glow_levels/1 a
		# /7, mais set_glow_level() indexe de 0 a 6. Les niveaux 2, 3 et 4 de
		# l'inspecteur sont donc les indices 1, 2 et 3.
		const NIVEAUX_GARDES := [1, 2, 3]
		for indice in range(0, 7):
			env.set_glow_level(indice, 1.0 if indice in NIVEAUX_GARDES else 0.0)

	# L'OMBRE DE CONTACT. Elle ne mord que l'ambiante, jamais la lumiere
	# directe : ssao_light_affect a 0. Autre valeur et on obtient des cernes
	# sales en plein midi, sous un soleil qui n'a aucune raison d'en produire.
	env.ssao_enabled = reglages.ssao
	if reglages.ssao:
		env.ssao_radius = reglages.ssao_rayon
		env.ssao_intensity = reglages.ssao_intensite
		env.ssao_power = reglages.ssao_puissance
		env.ssao_light_affect = 0.0
		# Aucun de nos materiaux ne porte de canal d'occlusion : les
		# generateurs cuisent une couleur de base et rien d'autre.
		env.ssao_ao_channel_affect = 0.0

	# CEUX-LA RESTENT COUPES, ET C'EST DELIBERE.
	#
	# SSIL rebondit la lumiere en espace ecran : cher, et invisible dans une
	# ville dont l'ambiante est deja forte. SDFGI construit un champ de
	# distance sur tout le monde ouvert — c'est l'effet le plus cher de Godot,
	# pour un gain que le brouillard mange a quarante metres.
	env.ssil_enabled = false
	env.sdfgi_enabled = false


const CIEL := "res://rendu/ciel_nuit.gdshader"

## Ou se tient la lune, en degres : hauteur au-dessus de l'horizon, puis
## orientation. A l'OPPOSE du soleil de midi, ce qui est aussi la seule
## position ou elle ne se retrouve jamais derriere lui.
const LUNE_HAUTEUR := 42.0
const LUNE_AZIMUT := -145.0


# Le ciel est un shader, et ses couleurs suivent l'heure comme le reste.
#
# Il est construit UNE FOIS et garde : refabriquer un Sky et son materiau a
# chaque relecture de l'heure — c'est-a-dire cinquante fois par seconde quand
# le cycle tourne — recompilerait le shader a chaque image.
func _configurer_ciel(env: Environment) -> void:
	var ciel := env.sky
	if ciel == null:
		ciel = Sky.new()
		# Basse resolution assumee, comme le reste du rendu : la voute n'a que
		# des degrades et des points, elle n'a pas besoin de 1024 pixels.
		ciel.radiance_size = Sky.RADIANCE_SIZE_128
		env.sky = ciel
	var mat := ciel.sky_material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = load(CIEL) as Shader
		ciel.sky_material = mat

	var nuit := Reglages.nuit_part()
	mat.set_shader_parameter("nuit", nuit)
	mat.set_shader_parameter("couleur_zenith", reglages.ciel())
	# L'horizon est toujours plus clair que le zenith, de jour comme de nuit :
	# c'est ce qui donne au ciel son volume.
	mat.set_shader_parameter("couleur_horizon",
			reglages.ciel().lerp(reglages.brume(), 0.55))
	mat.set_shader_parameter("lune_direction", _direction(
			LUNE_HAUTEUR, LUNE_AZIMUT))
	mat.set_shader_parameter("lune_couleur", reglages.lune_couleur)
	mat.set_shader_parameter("etoiles_seuil", reglages.etoiles_seuil)

	_configurer_lune(nuit)


static func _direction(hauteur_deg: float, azimut_deg: float) -> Vector3:
	var h := deg_to_rad(hauteur_deg)
	var a := deg_to_rad(azimut_deg)
	return Vector3(cos(h) * sin(a), sin(h), cos(h) * cos(a)).normalized()


# LA LUNE ECLAIRE, elle ne fait pas que se voir.
#
# C'est le fond du probleme signale : « quand il fait nuit, on ne voit
# absolument rien dans les endroits non eclaires ». Monter la seule lumiere
# ambiante aurait aplati la scene — une ambiante forte supprime les ombres et
# rend tout egal. Une lumiere directionnelle faible et froide, elle, garde le
# relief et donne une direction a la nuit.
func _configurer_lune(nuit: float) -> void:
	var scene := scene_3d()
	if scene == null:
		return
	var lune := scene.get_node_or_null("Lune") as DirectionalLight3D
	if lune == null:
		lune = DirectionalLight3D.new()
		lune.name = "Lune"
		scene.add_child(lune)
	lune.rotation_degrees = Vector3(-LUNE_HAUTEUR, LUNE_AZIMUT + 180.0, 0.0)
	lune.light_color = reglages.lune_couleur
	lune.light_energy = reglages.lune_energie * nuit
	# LA LUNE PORTE MAINTENANT SES OMBRES, et l'objection d'avant tenait :
	# « deux jeux d'ombres dans la meme scene se croisent et se contredisent ».
	# Elle tenait tant que les deux pouvaient etre allumes ensemble. Avec deux
	# seuils qui ne se recouvrent pas — le soleil s'arrete a 0,30 de jour, la
	# lune ne commence qu'a 0,70 de nuit — ils ne coexistent jamais, et la bande
	# entre les deux est l'aube et le crepuscule ou aucune ombre rasante n'est
	# lisible de toute facon.
	#
	# Ce que ca gagne : la voiture ne FLOTTE plus. Sans ombre au sol, de nuit,
	# elle etait posee sur rien.
	lune.shadow_enabled = nuit >= reglages.lune_ombres_seuil
	lune.directional_shadow_max_distance = reglages.lune_ombre_distance
	lune.visible = nuit > 0.02


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
	#
	# Le seuil est monte de 0,05 a un reglage (0,30) : entre les deux, le soleil
	# est si rasant que ses ombres traversent toute la rue en bouillie. Et c'est
	# ce qui laisse la place a celles de la lune sans jamais les croiser.
	soleil.shadow_enabled = reglages.soleil_ombres and jour >= reglages.soleil_ombres_seuil
	soleil.directional_shadow_max_distance = reglages.soleil_ombre_distance
	# Le soleil donne peu a l'air : une directionnelle eclaire TOUT le volume a
	# la fois, donc ce qui fait un joli rayon rasant a l'aube fait de la soupe
	# a midi.
	soleil.light_volumetric_fog_energy = reglages.soleil_volume
	soleil.visible = jour > 0.01


## La camera active du monde. Les autres systemes passent par ici plutot que
## de fouiller l'arbre, pour que la structure du viewport reste un detail.
func camera() -> Camera3D:
	return _viewport.get_camera_3d()


## Le noeud sous lequel tout le contenu 3D doit etre ajoute.
func scene_3d() -> Node3D:
	return $Rendu/Scene3D
