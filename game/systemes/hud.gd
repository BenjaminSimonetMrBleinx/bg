# L'affichage tete haute.
#
# Il vit DANS le SubViewport, donc rendu a 512 x 384 comme le reste. Un texte
# net superpose a une image basse resolution trahirait immediatement un jeu
# moderne : les HUD PS2 partageaient le meme tampon que la 3D, et c'est ce
# qui leur donne ce grain.
#
# Regle de conduite : n'afficher que ce qui change. Un compteur immobile a
# l'ecran pendant qu'on marche est du bruit, pas de l'information.
class_name Hud
extends Control

@export var reglages: Reglages
@export var vehicule: NodePath
@export var equipement: NodePath
@export var controleur: NodePath

var _v: Vehicule
var _eq: Equipement
var _c: Node

## Compte a rebours d'affichage du nom de l'outil, en secondes. L'objet
## equipe se voit dans la main : le nom n'a d'interet qu'a l'instant du
## changement, apres quoi il encombre.
var _annonce: float = 0.0
var _texte_annonce: String = ""

## Vitesse lissee. La valeur brute d'un VehicleBody3D oscille d'un ou deux
## km/h a chaque image ; affichee telle quelle, le compteur papillonne.
var _kmh: float = 0.0


func _ready() -> void:
	_v = get_node_or_null(vehicule) as Vehicule
	_eq = get_node_or_null(equipement) as Equipement
	_c = get_node_or_null(controleur)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _eq != null:
		_eq.change.connect(_sur_changement_outil)
	set_process(true)


func _sur_changement_outil(i: int) -> void:
	_texte_annonce = _eq.nom_de(i) if i >= 0 else "Mains vides"
	_annonce = reglages.hud_annonce


func _process(delta: float) -> void:
	if _annonce > 0.0:
		_annonce = maxf(0.0, _annonce - delta)
	if _v != null:
		var cible: float = absf(_v.vitesse_kmh())
		_kmh = lerpf(_kmh, cible, clampf(delta * 12.0, 0.0, 1.0))
	queue_redraw()


func _au_volant() -> bool:
	# On interroge le controleur plutot que de deviner : c'est lui qui possede
	# l'etat, et deux sources de verite finissent toujours par diverger.
	return _c != null and _c.call("au_volant")


func _draw() -> void:
	var police := get_theme_default_font()
	if police == null:
		return

	_version(police)

	if _au_volant():
		_compteur(police)

	if _annonce > 0.0:
		# Fondu sur le dernier tiers, pour que ca ne disparaisse pas d'un coup.
		var a := clampf(_annonce / maxf(0.01, reglages.hud_annonce * 0.33), 0.0, 1.0)
		_ecrire(police, _texte_annonce, Vector2(size.x / 2.0, size.y - 62.0),
				17, Color(0.949, 0.776, 0.42, a), true)


# La version, en haut a droite, en permanence.
#
# C'est la seule chose affichee tout le temps, et elle enfreint donc la regle
# de conduite du fichier. La raison la vaut : quand quelqu'un envoie une
# capture d'ecran en disant que quelque chose ne marche pas, la premiere
# question est toujours « tu es sur quelle version ». Elle est maintenant sur
# l'image.
#
# Assez petite et assez pale pour disparaitre du regard — 9 points a 512 de
# large, c'est la taille d'une mention legale.
func _version(police: Font) -> void:
	_ecrire(police, Version.texte(), Vector2(size.x - 6.0, 14.0), 9,
			Color(0.72, 0.70, 0.64, 0.55), false, HORIZONTAL_ALIGNMENT_RIGHT)


func _compteur(police: Font) -> void:
	var coin := Vector2(size.x - 16.0, size.y - 18.0)
	_ecrire(police, "%d" % roundi(_kmh), coin - Vector2(26.0, 0.0), 26,
			Color(0.949, 0.925, 0.867), false, HORIZONTAL_ALIGNMENT_RIGHT)
	_ecrire(police, "km/h", coin, 12, Color(0.72, 0.70, 0.64), false,
			HORIZONTAL_ALIGNMENT_RIGHT)


# Contour noir puis texte : sans lui, un chiffre clair passe devant un phare
# ou une facade claire et devient illisible une seconde sur trois.
func _ecrire(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color, centre: bool,
		alignement: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille).x
	var p := ou
	if centre:
		p.x -= largeur / 2.0
	elif alignement == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= largeur

	var ombre := Color(0.043, 0.055, 0.086, couleur.a)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		police.draw_string(get_canvas_item(), p + d, texte,
				HORIZONTAL_ALIGNMENT_LEFT, -1, taille, ombre)
	police.draw_string(get_canvas_item(), p, texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
