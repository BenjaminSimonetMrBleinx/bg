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
	{"cle": "purete", "nom": "Purete du produit", "genre": CHOIX},
	{"cle": "famille", "nom": "Points de famille", "genre": CHOIX},
	{"cle": "reputation", "nom": "Reputation de rue", "genre": CHOIX},
	{"cle": "densite", "nom": "Foule et trafic", "genre": CHOIX},
	{"cle": "collisions", "nom": "Montrer les collisions", "genre": BASCULE},
	{"cle": "reperes", "nom": "Montrer les lieux nommes", "genre": BASCULE},
	{"cle": "jauge", "nom": "Releve de performance", "genre": BASCULE},
	{"cle": "resolution", "nom": "Resolution interne", "genre": CHOIX},
	{"cle": "ambiance", "nom": "Ambiance", "genre": BASCULE},
	{"cle": "musique", "nom": "Musique", "genre": BASCULE},
]

## Les trois crans de peuplement : rien, ce que le jeu pose, et le maximum.
##
## LA FOULE EST A ZERO DANS LE JEU, ET C'EST VOULU depuis le 31/07/2026 : la
## voie des passants se calcule avec un ecart de trottoir UNIQUE, faux des que
## les rues changent de largeur — six sur vingt-six marchaient sur la chaussee.
## L'allumer ici montre donc un defaut connu, et c'est justement a ca que sert
## un outil de test : celui qui reparera les trottoirs a besoin de les voir.
const DENSITES_NOM := ["aucun", "normal", "maximum"]
const FOULE := [0, 26, 120]
const TRAFIC := [0, 10, 60]

## Au-dela de cette distance du joueur, on ne fabrique pas de maillage de
## controle : la ville en compte des milliers, et les afficher tous ferait
## tomber le jeu au moment precis ou l'on cherche pourquoi il tombe.
const COLLISIONS_PORTEE := 45.0
const COLLISIONS_MAX := 400

@export var reglages: Reglages
@export var bourse: NodePath
@export var equipement: NodePath
@export var joueur: NodePath
@export var vehicule: NodePath
@export var foule: NodePath
@export var trafic: NodePath
@export var jauge: NodePath
@export var purete: NodePath
## La racine du contenu 3D : c'est sous elle qu'on cherche les collisions et
## qu'on pose les reperes.
@export var scene_3d: NodePath
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
var _foule: Foule
var _trafic: Trafic
var _jauge: JaugePerf
var _purete: Purete
var _famille: Famille
var _reputation: Reputation
var _scene: Node3D

## Ce qu'on a fabrique pour montrer. Garde pour pouvoir le DEFAIRE : des
## maillages de controle laisses en place apres extinction sont pires que pas
## de controle du tout, on croit voir le jeu et on voit l'outil.
var _montre_collisions: Node3D
var _montre_reperes: Node3D


func _ready() -> void:
	_bourse = get_node_or_null(bourse) as Bourse
	_equipement = get_node_or_null(equipement) as Equipement
	_joueur = get_node_or_null(joueur) as Joueur
	_vehicule = get_node_or_null(vehicule) as Node3D
	_rendu = get_node_or_null(rendu)
	_foule = get_node_or_null(foule) as Foule
	_trafic = get_node_or_null(trafic) as Trafic
	_jauge = get_node_or_null(jauge) as JaugePerf
	_purete = get_node_or_null(purete) as Purete
	_famille = Famille.courante(self)
	_reputation = Reputation.courante(self)
	_scene = get_node_or_null(scene_3d) as Node3D
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
		"densite":
			return DENSITES_NOM[_rang_densite()]
		"purete":
			# LE NOM, JAMAIS LE NUMERO, meme ici. Un outil de test qui afficherait
			# « 3 / 5 » apprendrait au joueur qu'il y a une echelle, et c'est
			# exactement ce que la direction du jeu refuse de lui dire.
			return _purete.nom() if _purete != null else "-"
		"famille":
			return str(_famille.points()) if _famille != null else "-"
		"reputation":
			return str(_reputation.points()) if _reputation != null else "-"
		"collisions":
			return "oui" if _montre_collisions != null else "non"
		"reperes":
			return "oui" if _montre_reperes != null else "non"
		"jauge":
			return "oui" if _jauge != null and _jauge.visible else "non"
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
		"temps", "resolution", "densite", "purete", "famille", "reputation":
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
		"collisions":
			return _basculer_les_collisions()
		"reperes":
			return _basculer_les_reperes()
		"jauge":
			if _jauge == null:
				return "pas de jauge"
			_jauge.visible = not _jauge.visible
			if _jauge.visible:
				# On repart de zero : les images d'un menu ouvert ne disent rien
				# de ce qu'on s'appretait a regarder.
				_jauge.repartir()
			return "releve affiche" if _jauge.visible else "releve cache"
		"ambiance":
			return _basculer_le_bus(Audio.BUS_AMBIANCE, "ambiance")
		"musique":
			return _basculer_le_bus("Musique", "musique")
	return ""


## Declenche une ligne par sa CLE plutot que par son rang. Sert aux captures et
## aux tests : un rang change des qu'on insere une ligne au-dessus, une cle non.
func basculer(cle: String) -> String:
	for i in ENTREES.size():
		if str(ENTREES[i].get("cle", "")) == cle:
			return agir(i)
	return "cle '%s' inconnue" % cle


## A ou D sur la ligne i. Ne concerne que les choix ; ailleurs, F suffit.
func regler(i: int, sens: int) -> void:
	match str(ENTREES[i].get("cle", "")):
		"temps":
			_poser_vitesse(_rang_vitesse() + sens)
		"resolution":
			_poser_resolution(_rang_resolution() + sens)
		"densite":
			_poser_densite(_rang_densite() + sens)
		"purete":
			if _purete != null:
				_purete.poser(_purete.palier() + sens)
		"reputation":
			if _reputation != null:
				_reputation.ajouter(sens * 10)
		"famille":
			# Par dix : parcourir cent points un par un au clavier serait
			# inutilisable, et personne ne regle un compteur de test au point
			# pres.
			if _famille != null:
				_famille.ajouter(sens * 10)


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
	var ou := _ou_est(nom)
	if ou == Vector3.INF:
		return "lieu '%s' inconnu" % nom
	# UN METRE AU-DESSUS, et la vitesse coupee. Une ancre est posee AU SOL : y
	# deposer une capsule la fait naitre a moitie dans le trottoir, et la
	# physique l'ejecte a la premiere image.
	_joueur.global_position = ou + Vector3.UP
	_joueur.velocity = Vector3.ZERO
	return "arrive a %s" % nom


## Ou se trouve un lieu, destination de l'histoire ou parcelle du generateur, ou
## Vector3.INF s'il n'existe pas. Les reperes et la teleportation lisent la meme
## reponse : deux resolutions differentes finiraient par se contredire.
func _ou_est(nom: String) -> Vector3:
	for d in DESTINATIONS:
		if str(d[0]) != nom:
			continue
		var n := _noeud_de_scene(str(d[1]))
		return n.global_position if n != null else Vector3.INF
	var fiche := Ancrage.trouver(nom)
	if fiche.is_empty():
		return Vector3.INF
	var p: Array = fiche.get("pos", [0, 0, 0])
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


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


# --------------------------------------------------------------- le peuplement


func _rang_densite() -> int:
	var n := _trafic.combien if _trafic != null else 0
	if _foule != null:
		n = maxi(n, _foule.combien)
	if n <= 0:
		return 0
	# Le cran du haut se reconnait au-dela du double du normal, pas a l'egalite :
	# un effectif regle a la main dans l'editeur ne tomberait sinon dans aucun.
	return 2 if n > TRAFIC[1] * 2 else 1


func _poser_densite(rang: int) -> void:
	var r := clampi(rang, 0, DENSITES_NOM.size() - 1)
	if _foule != null:
		_foule.repeupler(FOULE[r])
	if _trafic != null:
		_trafic.repeupler(TRAFIC[r])


# ------------------------------------------------------------- ce qu'on montre


# LES COLLISIONS, AUTOUR DU JOUEUR SEULEMENT.
#
# Godot n'a pas d'interrupteur a chaud : debug_collisions_hint ne vaut qu'a la
# construction des formes, donc il ne montrerait rien d'une ville deja batie. On
# fabrique donc un maillage de controle par forme — et surtout pas pour toutes :
# la ville en compte des milliers, et les afficher en bloc ferait tomber le jeu
# a l'instant precis ou l'on cherche pourquoi il tombe.
func _basculer_les_collisions() -> String:
	if _montre_collisions != null:
		_montre_collisions.queue_free()
		_montre_collisions = null
		return "collisions cachees"
	if _scene == null or _joueur == null:
		return "pas de scene"

	var porte := Node3D.new()
	porte.name = "CollisionsDev"
	_scene.add_child(porte)
	_montre_collisions = porte

	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.albedo_color = Color(0.30, 1.0, 0.45, 0.55)
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.cull_mode = BaseMaterial3D.CULL_DISABLED

	var formes: Array[CollisionShape3D] = []
	_recolter(_scene, formes)

	var pose := 0
	var vus := 0
	for f in formes:
		if f.shape == null or f.disabled:
			continue
		vus += 1
		if f.global_position.distance_to(_joueur.global_position) > COLLISIONS_PORTEE:
			continue
		if pose >= COLLISIONS_MAX:
			continue
		var m := MeshInstance3D.new()
		m.mesh = f.shape.get_debug_mesh()
		m.material_override = matiere
		porte.add_child(m)
		m.global_transform = f.global_transform
		pose += 1

	# On DIT ce qu'on a laisse de cote. Un plafond silencieux se lit comme
	# « tout est montre », et on conclut qu'un mur n'a pas de collision alors
	# qu'il etait simplement le quatre-cent-unieme.
	return "%d forme(s) sur %d, a moins de %d m" % [pose, vus, int(COLLISIONS_PORTEE)]


func _recolter(n: Node, sortie: Array[CollisionShape3D]) -> void:
	if n is CollisionShape3D:
		sortie.append(n)
	for e in n.get_children():
		_recolter(e, sortie)


# LES LIEUX NOMMES, DEBOUT DANS LA VILLE. Un Label3D plutot qu'un piquet : le
# nom est ce qu'on cherche — savoir qu'il y a « quelque chose » ici ne sert a
# rien quand on tient deja la liste de tout ce qui existe.
func _basculer_les_reperes() -> String:
	if _montre_reperes != null:
		_montre_reperes.queue_free()
		_montre_reperes = null
		return "reperes caches"
	if _scene == null:
		return "pas de scene"

	var porte := Node3D.new()
	porte.name = "ReperesDev"
	_scene.add_child(porte)
	_montre_reperes = porte

	var poses := 0
	for nom in lieux():
		var ou := _ou_est(str(nom))
		if ou == Vector3.INF:
			continue
		var e := Label3D.new()
		e.text = str(nom)
		e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		e.no_depth_test = true
		e.font_size = 96
		e.pixel_size = 0.008
		e.modulate = Color(0.95, 0.78, 0.42)
		e.outline_modulate = Color(0, 0, 0, 0.9)
		porte.add_child(e)
		# A hauteur d'homme et demi : au sol le nom se perd dans le trottoir,
		# trop haut il flotte sans designer quoi que ce soit.
		e.global_position = ou + Vector3.UP * 2.6
		poses += 1
	return "%d repere(s) poses" % poses


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
