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

var _de: int = -1
var _vers: int = -1

var _silhouette: Silhouette
var _vers_arrivee: bool = true
var _attente: float = 0.0
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)


func _ready() -> void:
	if reglages == null:
		push_error("pieton : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	_silhouette = Silhouette.new(reglages)
	_silhouette.recenser(self)
	# Chacun demarre a un moment different de son trajet, sinon toute la rue
	# fait demi-tour en meme temps.
	_attente = randf() * pause


## Pose le passant sur le graphe, entre deux carrefours. Sans appel a cette
## methode il retombe sur l'aller-retour entre depart et arrivee.
func sur_le_graphe(tous: Array, liens: Dictionary, de: int, vers: int,
		largeur: float) -> void:
	noeuds = tous
	voisins = liens
	ecart = largeur
	_de = de
	_vers = vers
	depart = _sur_le_trottoir(_de, _vers)
	arrivee = _sur_le_trottoir(_vers, _de)
	_vers_arrivee = true


# Le trottoir est a l'ECART de l'axe de la rue, et du bon cote : celui de
# droite dans le sens de marche. Sans ce choix de cote, deux passants en sens
# inverse se traversent au milieu de la chaussee.
func _sur_le_trottoir(i: int, autre: int) -> Vector3:
	var a := _noeud(i)
	var b := _noeud(autre)
	var direction := (b - a).normalized()
	var droite := Vector3(-direction.z, 0.0, direction.x)
	return a + droite * ecart + Vector3(0.0, 0.2, 0.0)


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
	arrivee = _sur_le_trottoir(_vers, _de)
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

	if voulu.length_squared() > 0.01:
		rotation.y = rotate_toward(rotation.y, Joueur.lacet_vers(voulu),
				reglages.marche_rotation * delta)

	_silhouette.avancer(Vector2(velocity.x, velocity.z).length(), delta)
