# Un passant.
#
# Il marche d'un carrefour a l'autre, et choisit sa rue en arrivant. Aucune
# recherche de chemin, aucune intention : une foule credible ne demande pas
# d'intelligence, elle demande du MOUVEMENT et de la VARIETE.
#
# CE QUI A CHANGE, ET POURQUOI.
#
# Il faisait auparavant un aller-retour sur un bout de trottoir fixe, pour
# toujours. Ca tient trente secondes : au-dela, on voit que le meme homme
# refait les memes vingt-cinq metres, ne tourne jamais un coin, et n'entre
# nulle part. Le decalage de depart aleatoire masquait le probleme au premier
# coup d'oeil ; il ne le resolvait pas.
#
# Maintenant il suit le graphe des rues — le meme que les voitures, a la voie
# pres : elles prennent leur file de droite, lui le milieu du trottoir. Il
# tourne aux carrefours, ne repasse plus au meme endroit, et on peut le suivre
# une minute sans voir la ficelle.
#
# La demarche est celle du joueur, au sens propre : le meme silhouette.gd.
class_name Pieton
extends CharacterBody3D

@export var reglages: Reglages

## Point de depart et point d'arrivee du va-et-vient, en coordonnees monde.
@export var depart: Vector3
@export var arrivee: Vector3

## Multiplie la vitesse de marche. Une foule ou tout le monde avance a la
## meme allure se lit immediatement comme du decor anime.
@export_range(0.3, 1.6, 0.01) var allure: float = 1.0

## Temps d'arret aux extremites, en secondes. Un demi-tour instantane est ce
## qui trahit le plus vite un aller-retour scripte.
@export_range(0.0, 6.0, 0.1) var pause: float = 1.2

## Le graphe des rues, partage par tous. Vide : on retombe sur l'aller-retour
## entre depart et arrivee, ce qui reste utilisable si la ville n'a pas encore
## ete regeneree avec un graphe.
var noeuds: Array = []
var voisins: Dictionary = {}
var ecart: float = 7.0            # du milieu de la chaussee au milieu du trottoir

## De combien on s'ecarte du centre d'un carrefour avant que le trottoir
## commence. Sur le carrefour lui-meme il n'y a pas de trottoir : c'est un
## carre d'asphalte, et un passant pose la se tient sur la chaussee.
var retrait: float = 8.5

## Le cote de la ville, en metres. Sert a une seule chose, et elle se voit :
## les rues du POURTOUR n'ont de trottoir que du cote interieur, l'autre donne
## sur le desert. Sans cette borne, un passant sur huit marche dans le sable le
## long de la derniere rue. Zero = on ne sait pas, on ne corrige rien.
var etendue: float = 0.0

## Distance reellement MARCHEE, en metres, depuis la creation.
##
## Elle existe pour le test, et pour une raison qui n'est pas cosmetique :
## comparer deux positions ne dit plus si quelqu'un avance depuis que la foule
## se recycle autour du joueur. Une teleportation compte cent metres qu'aucune
## jambe n'a faits, et un passant coince contre une poubelle passerait pour le
## plus actif de la rue.
var parcouru: float = 0.0

var _de: int = -1
var _vers: int = -1

## LA MARCHE, EN DEUX IMPLEMENTATIONS, comme pour le joueur.
##
##   - Demarche   pour un modele a squelette, qui porte ses propres clips
##   - Silhouette pour un maillage segmente, anime par du code
##
## Les deux exposent avancer(vitesse, delta). Le passant prend la premiere qui
## veut de lui : un figurant du pack a un squelette et un AnimationPlayer, les
## boites generees n'ont ni l'un ni l'autre. C'est le meme choix que fait
## joueur.gd depuis que Walter est passe au squelette — et c'etait la
## condition pour que les vrais modeles entrent dans la rue.
var _marche: RefCounted
var _vers_arrivee: bool = true
var _attente: float = 0.0
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)


func _ready() -> void:
	if reglages == null:
		push_error("pieton : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	var d := Demarche.new(reglages)
	if d.recenser(self):
		_marche = d
	else:
		var sil := Silhouette.new(reglages)
		sil.recenser(self)
		_marche = sil
	# Chacun demarre a un moment different de son trajet, sinon toute la rue
	# fait demi-tour en meme temps.
	_attente = randf() * pause


## Pose le passant sur le graphe, entre deux carrefours. Sans appel a cette
## methode il retombe sur l'aller-retour entre depart et arrivee.
func sur_le_graphe(tous: Array, liens: Dictionary, de: int, vers: int,
		largeur: float, recul: float = 8.5) -> void:
	noeuds = tous
	voisins = liens
	ecart = largeur
	retrait = recul
	_de = de
	_vers = vers
	depart = _bord(_de, _vers, false)
	arrivee = _bord(_de, _vers, true)
	_vers_arrivee = true


# Le trottoir est a l'ECART de l'axe de la rue, et du bon cote : celui de
# droite dans le sens de marche. Sans ce choix de cote, deux passants en sens
# inverse se traversent au milieu de la chaussee.
#
# LES DEUX BOUTS SE CALCULENT DEPUIS LA MEME DIRECTION, et c'est tout l'objet
# de cette fonction. La version precedente demandait le depart au troncon
# a->b et l'arrivee au troncon b->a : la droite de l'un est la gauche de
# l'autre, donc le passant partait du trottoir de droite et visait celui d'en
# face. Il traversait la chaussee en diagonale a chaque troncon, ce que
# personne n'a vu pendant six versions parce que foule.gd construisait le
# graphe sans jamais poser les passants dessus. Mesure du 30/07/2026 : 14
# passants sur 16 se tenaient a 0,01 m, la hauteur de la chaussee.
func _bord(a: int, b: int, au_bout: bool) -> Vector3:
	var pa := _noeud(a)
	var pb := _noeud(b)
	var direction := (pb - pa).normalized()
	var droite := Vector3(-direction.z, 0.0, direction.x)
	# Ecarte de l'axe, ET recule du carrefour : le trottoir ne commence qu'a la
	# sortie du croisement. Le bout de troncon s'arrete de meme avant le
	# carrefour suivant — c'est la que le passant tourne, et c'est la qu'un
	# pieton s'arrete avant de traverser.
	var base := (pb - direction * retrait) if au_bout else (pa + direction * retrait)
	# Le trottoir de droite, SAUF s'il n'y en a pas de ce cote — alors celui de
	# gauche. C'est le cas des rues du pourtour, dont le cote exterieur donne
	# sur le desert.
	if not _dans_la_ville(base + droite * ecart):
		droite = -droite
	return base + droite * ecart + Vector3(0.0, 0.2, 0.0)


# La marge est le RETRAIT, pas zero. La ville va bien de 0 a son etendue, mais
# les trois premiers metres de la rue du pourtour sont du sable : les trottoirs
# appartiennent aux ilots, et il n'y a pas d'ilot au-dela du dernier. Tester
# contre le bord exact laissait donc deux passants sur seize marcher dans le
# desert le long de la derniere rue, ce qui est precisement le defaut qu'on
# voulait corriger.
func _dans_la_ville(p: Vector3) -> bool:
	if etendue <= 0.0:
		return true
	return (p.x >= retrait and p.x <= etendue - retrait
			and p.z <= -retrait and p.z >= -(etendue - retrait))


func _noeud(i: int) -> Vector3:
	var p: Array = noeuds[i]
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


# Au carrefour, une rue au sort — mais pas celle d'ou l'on vient, sauf
# impasse. Sans cette regle, un passant sur deux fait demi-tour a chaque coin
# et la rue a l'air de bouillir sur place.
func _choisir_la_suite() -> void:
	var possibles: Array = voisins.get(_vers, [])
	if possibles.is_empty():
		_vers_arrivee = not _vers_arrivee
		return
	var sans_retour: Array = possibles.filter(func(v: int) -> bool: return v != _de)
	var suite: Array = sans_retour if not sans_retour.is_empty() else possibles
	_de = _vers
	_vers = suite[randi() % suite.size()]
	depart = global_position
	arrivee = _bord(_de, _vers, true)
	_vers_arrivee = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravite * delta

	var cible := arrivee if _vers_arrivee else depart
	var vers := cible - global_position
	vers.y = 0.0

	if vers.length() < 0.6:
		_attente += delta
		if _attente > pause:
			if noeuds.is_empty():
				_vers_arrivee = not _vers_arrivee
			else:
				_choisir_la_suite()
			_attente = 0.0
		vers = Vector3.ZERO

	var voulu := vers.normalized() if vers.length() > 0.01 else Vector3.ZERO
	var vitesse := reglages.marche_vitesse * allure
	var k := clampf(reglages.marche_acceleration * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, voulu.x * vitesse, k)
	velocity.z = lerpf(velocity.z, voulu.z * vitesse, k)

	move_and_slide()
	parcouru += Vector2(velocity.x, velocity.z).length() * delta

	if voulu.length_squared() > 0.01:
		rotation.y = rotate_toward(rotation.y, Joueur.lacet_vers(voulu),
				reglages.marche_rotation * delta)

	if _marche != null:
		_marche.avancer(Vector2(velocity.x, velocity.z).length(), delta)
