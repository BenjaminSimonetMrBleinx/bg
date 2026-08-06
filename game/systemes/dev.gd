# Les outils de test.
#
# Tout ce qui sert a ALLER PLUS VITE quand on verifie quelque chose : poser
# l'heure en marche, se donner de quoi jouer, faire venir la voiture, couper une
# ambiance qui gene. Rien ici n'appartient au jeu.
#
# CE FICHIER NE DESSINE RIEN. Il tient la liste de ce qu'on peut faire et sait
# le faire ; c'est le menu pause qui l'affiche, exactement comme il affiche ses
# options. Un second menu dessine a la main aurait duplique la conversion de la
# souris, la mise en pause, le cadre et les sons — pour les memes lignes.
#
# POURQUOI CE N'EST PAS CACHE DERRIERE UN DRAPEAU. Ceux qui jouent a ce jeu sont
# ceux qui le testent. Un outil que Guillaume ne sait pas qu'il a ne sert a
# rien, et une option de developpement visible n'a jamais gene personne dans un
# jeu de fan.
class_name Dev
extends Node

## Les trois formes qu'une ligne peut prendre.
##   action   F declenche, il n'y a rien a lire a droite
##   bascule  F inverse, on lit oui/non
##   choix    A et D parcourent des valeurs nommees
const ACTION := "action"
const BASCULE := "bascule"
const CHOIX := "choix"
## Une quatrieme forme : la ligne n'agit pas, elle OUVRE une seconde page. Les
## quarante et un lieux nommes ne tiennent pas dans un cadre de 384 pixels.
const PAGE := "page"

## La vitesse du temps par defaut, celle de reglages.gd : une heure de jeu par
## minute reelle. On ne la reecrit pas ici — on la relit au demarrage, pour que
## changer le defaut du jeu change aussi ce que « normale » veut dire.
const VITESSES_NOM := ["figee", "normale", "x10"]

## Les resolutions internes proposees, toutes en 4:3 comme le rendu du jeu. La
## grande sert a voir ce qu'une geometrie contient vraiment, la petite a juger
## ce qui reste lisible quand tout est ecrase.
const RESOLUTIONS := [Vector2i(256, 192), Vector2i(512, 384), Vector2i(1024, 768)]
const RESOLUTIONS_NOM := ["256", "512", "1024"]

## L'ordre est celui de la lecture, pas celui de l'implementation : le temps et
## le deplacement d'abord, parce que c'est ce qu'on vient chercher.
const ENTREES := [
	{"cle": "temps", "nom": "Vitesse du temps", "genre": CHOIX},
	{"cle": "lieu", "nom": "Aller a un lieu nomme...", "genre": PAGE},
	{"cle": "traverse", "nom": "Traverser les murs et voler", "genre": BASCULE},
	{"cle": "voiture", "nom": "Faire venir la voiture", "genre": ACTION},
	{"cle": "mille", "nom": "Donner 1 000 $", "genre": ACTION},
	{"cle": "dix_mille", "nom": "Donner 10 000 $", "genre": ACTION},
	{"cle": "sans_le_sou", "nom": "Remettre l'argent a zero", "genre": ACTION},
	{"cle": "outils", "nom": "Donner tous les outils", "genre": ACTION},
	{"cle": "invulnerable", "nom": "Invulnerable", "genre": BASCULE},
	{"cle": "soigner", "nom": "Se soigner", "genre": ACTION},
	{"cle": "resolution", "nom": "Resolution interne", "genre": CHOIX},
	{"cle": "ambiance", "nom": "Ambiance", "genre": BASCULE},
	{"cle": "musique", "nom": "Musique", "genre": BASCULE},
]

@export var reglages: Reglages
@export var bourse: NodePath
@export var equipement: NodePath
@export var joueur: NodePath
@export var vehicule: NodePath
## Le noeud qui porte le pipeline de rendu — la racine du monde. Son
## appliquer() relit reglages.tres a chaud, ce qui est exactement ce qu'il faut
## pour changer la resolution sans relancer.
@export var rendu: NodePath

var _vitesse_normale: float = 0.015
var _bourse: Bourse
var _equipement: Equipement
var _joueur: Joueur
var _vehicule: Node3D
var _rendu: Node


func _ready() -> void:
	_bourse = get_node_or_null(bourse) as Bourse
	_equipement = get_node_or_null(equipement) as Equipement
	_joueur = get_node_or_null(joueur) as Joueur
	_vehicule = get_node_or_null(vehicule) as Node3D
	_rendu = get_node_or_null(rendu)
	if reglages != null:
		_vitesse_normale = reglages.temps_vitesse


# ------------------------------------------------------------------- lecture


func nombre() -> int:
	return ENTREES.size()


func nom(i: int) -> String:
	return str(ENTREES[i].get("nom", ""))


func genre(i: int) -> String:
	return str(ENTREES[i].get("genre", ACTION))


## Ce qui s'affiche a droite de la ligne. Vide pour une action : il n'y a pas
## d'etat a lire, seulement un geste a declencher.
func valeur(i: int) -> String:
	match str(ENTREES[i].get("cle", "")):
		"temps":
			return VITESSES_NOM[_rang_vitesse()]
		"resolution":
			return RESOLUTIONS_NOM[_rang_resolution()]
		"invulnerable":
			return "oui" if _joueur != null and _joueur.invulnerable else "non"
		"traverse":
			return "oui" if _joueur != null and _joueur.traverse else "non"
		"ambiance":
			return "coupee" if _muet(Audio.BUS_AMBIANCE) else "active"
		"musique":
			return "coupee" if _muet("Musique") else "active"
	return ""


# --------------------------------------------------------------------- agir


## F sur la ligne i. Renvoie une phrase courte a afficher, ou "" s'il n'y a
## rien a dire : un outil qui agit sans le confirmer laisse croire qu'il n'a
## rien fait, et on appuie trois fois.
func agir(i: int) -> String:
	match str(ENTREES[i].get("cle", "")):
		"temps", "resolution":
			# Un choix se parcourt a gauche-droite ; F le fait avancer d'un cran
			# plutot que de ne rien faire.
			regler(i, 1)
			return ""
		"traverse":
			if _joueur == null:
				return "pas de joueur"
			_joueur.traverser(not _joueur.traverse)
			return "on traverse tout" if _joueur.traverse \
					else "repose au sol"
		"voiture":
			return _amener_la_voiture()
		"mille":
			return _donner_argent(1000)
		"dix_mille":
			return _donner_argent(10000)
		"sans_le_sou":
			if _bourse == null:
				return "pas de bourse"
			_bourse.poser(0)
			return "argent remis a zero"
		"outils":
			return _donner_les_outils()
		"invulnerable":
			if _joueur == null:
				return "pas de joueur"
			_joueur.invulnerable = not _joueur.invulnerable
			return "invulnerable" if _joueur.invulnerable else "vulnerable"
		"soigner":
			return _soigner()
		"ambiance":
			return _basculer_le_bus(Audio.BUS_AMBIANCE, "ambiance")
		"musique":
			return _basculer_le_bus("Musique", "musique")
	return ""


## A ou D sur la ligne i. Ne concerne que les choix ; ailleurs, F suffit.
func regler(i: int, sens: int) -> void:
	match str(ENTREES[i].get("cle", "")):
		"temps":
			_poser_vitesse(_rang_vitesse() + sens)
		"resolution":
			_poser_resolution(_rang_resolution() + sens)


# ------------------------------------------------------------------ les lieux


## Les endroits qui comptent, mis EN TETE de la liste.
##
## LA LISTE DU GENERATEUR NE SUFFIT PAS, et la premiere capture l'a montre :
## elle publie des parcelles — terrain_vague_6_7, parking_4_3 — et pas les
## endroits de l'histoire, qui sont des noeuds de la scene. « Chez Walter » est
## ce qu'on demande neuf fois sur dix, et il n'y figurait pas.
##
## Les positions sont relues SUR LES NOEUDS au moment d'y aller, jamais
## recopiees ici : la maison de Walter est posee par le generateur, donc elle
## bouge des qu'une rue change de largeur. C'est exactement le piege que
## l'ancrage existe pour eviter, et le recopier ici l'aurait reintroduit.
const DESTINATIONS := [
	["Chez Walter", "Rendu/Scene3D/Maisons/Walter"],
	["Chez Jesse", "Rendu/Scene3D/Maisons/Jesse"],
	["L'Alpine", "Rendu/Scene3D/Alpine"],
	["Le desert", "Rendu/Scene3D/Desert"],
]


## Les lieux ou l'on peut se rendre : les endroits de l'histoire d'abord, puis
## les parcelles du generateur, triees. Celles-ci suivent la ville qu'on a
## fabriquee — une seconde liste ecrite a la main se perimerait a la premiere
## regeneration.
func lieux() -> Array:
	var sortie: Array = []
	for d in DESTINATIONS:
		if _noeud_de_scene(str(d[1])) != null:
			sortie.append(str(d[0]))
	sortie.append_array(Ancrage.noms())
	return sortie


func _noeud_de_scene(chemin: String) -> Node3D:
	if _rendu == null:
		return null
	return _rendu.get_node_or_null(NodePath(chemin)) as Node3D


## Depose le joueur sur un lieu nomme.
##
## La voiture ne suit pas : on y va le plus souvent pour REGARDER quelque chose,
## et faire tomber une berline sur soi a l'arrivee serait le contraire du
## service rendu. Elle a sa propre ligne pour ca.
func aller_a(nom: String) -> String:
	if _joueur == null:
		return "pas de joueur"

	var ou := Vector3.INF
	for d in DESTINATIONS:
		if str(d[0]) != nom:
			continue
		var n := _noeud_de_scene(str(d[1]))
		if n != null:
			ou = n.global_position
		break

	if ou == Vector3.INF:
		var fiche := Ancrage.trouver(nom)
		if fiche.is_empty():
			return "lieu '%s' inconnu" % nom
		var p: Array = fiche.get("pos", [0, 0, 0])
		ou = Vector3(float(p[0]), float(p[1]), float(p[2]))

	# UN METRE AU-DESSUS, et la vitesse coupee. Une ancre est posee AU SOL : y
	# deposer une capsule la fait naitre a moitie dans le trottoir, et la
	# physique l'ejecte a la premiere image.
	_joueur.global_position = ou + Vector3.UP
	_joueur.velocity = Vector3.ZERO
	return "arrive a %s" % nom


# ------------------------------------------------------------------- le temps


func _rang_vitesse() -> int:
	if reglages == null:
		return 1
	var v := reglages.temps_vitesse
	if v <= 0.0001:
		return 0
	# Au-dessus du double de la normale, c'est l'accelere : le seuil est au
	# milieu plutot qu'a l'egalite, sinon un reglage laisse a 0,016 par un
	# curseur d'options ne se reconnait dans aucun des trois crans.
	return 2 if v > _vitesse_normale * 2.0 else 1


func _poser_vitesse(rang: int) -> void:
	if reglages == null:
		return
	var r := clampi(rang, 0, VITESSES_NOM.size() - 1)
	reglages.temps_vitesse = [0.0, _vitesse_normale, _vitesse_normale * 10.0][r]


# --------------------------------------------------------------- la resolution


func _rang_resolution() -> int:
	if reglages == null:
		return 1
	for r in RESOLUTIONS.size():
		if RESOLUTIONS[r].x == reglages.largeur_rendu:
			return r
	return 1


func _poser_resolution(rang: int) -> void:
	if reglages == null or _rendu == null or not _rendu.has_method("appliquer"):
		return
	var taille: Vector2i = RESOLUTIONS[clampi(rang, 0, RESOLUTIONS.size() - 1)]
	reglages.largeur_rendu = taille.x
	reglages.hauteur_rendu = taille.y
	# appliquer() relit la ressource et reconfigure le viewport a chaud. C'est
	# le chemin qu'emprunte deja un reglage change dans l'editeur, projet lance.
	_rendu.call("appliquer")


# ----------------------------------------------------------------- les gestes


func _donner_argent(somme: int) -> String:
	if _bourse == null:
		return "pas de bourse"
	_bourse.ajouter(somme)
	# Bourse.ecrire met les separateurs : « 10,000 » se lit du premier coup la
	# ou « 10000 » se lit une fois sur deux.
	return "+%s" % Bourse.ecrire(somme)


func _donner_les_outils() -> String:
	if _equipement == null:
		return "pas d'equipement"
	var n := 0
	for cle in _equipement.toutes_les_cles():
		if _equipement.donner(str(cle)):
			n += 1
	return "rien de neuf" if n == 0 else "%d objet(s) donne(s)" % n


func _soigner() -> String:
	if _joueur == null:
		return "pas de joueur"
	if _joueur.vivant():
		_joueur.pv = 100.0
		return "remis d'aplomb"
	# Mort, on le remet debout : c'est ce qu'on attend d'un bouton de test quand
	# on vient de se faire abattre en allant verifier autre chose.
	_joueur.ressusciter()
	return "ressuscite"


# LA VOITURE VIENT A NOUS, pas l'inverse. Elle se pose DEVANT le joueur et non
# dessus : apparaitre dans le meme volume que lui les fait s'ejecter tous les
# deux, et on passe la minute suivante a chercher ou la voiture est partie.
func _amener_la_voiture() -> String:
	if _vehicule == null or _joueur == null:
		return "pas de vehicule"
	var devant := -_joueur.global_transform.basis.z
	devant.y = 0.0
	if devant.length_squared() < 0.001:
		devant = Vector3.FORWARD
	_vehicule.global_position = _joueur.global_position \
			+ devant.normalized() * 4.5 + Vector3.UP * 0.2
	if "velocity" in _vehicule:
		_vehicule.set("velocity", Vector3.ZERO)
	return "voiture devant vous"


# ------------------------------------------------------------------- le son


func _muet(bus: String) -> bool:
	var i := AudioServer.get_bus_index(bus)
	return i >= 0 and AudioServer.is_bus_mute(i)


func _basculer_le_bus(bus: String, quoi: String) -> String:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return "bus '%s' introuvable" % bus
	var muet := not AudioServer.is_bus_mute(i)
	AudioServer.set_bus_mute(i, muet)
	return ("%s coupee" if muet else "%s rendue") % quoi
