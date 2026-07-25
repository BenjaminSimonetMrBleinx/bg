# Un passant.
#
# Il fait l'aller-retour sur un segment de trottoir, et rien d'autre. Aucune
# recherche de chemin, aucune decision : le generateur lui donne un point de
# depart, une direction et une longueur, et il arpente.
#
# C'est volontaire, et c'est ce que faisaient les jeux de l'epoque. Une foule
# credible ne demande pas d'intelligence — elle demande du MOUVEMENT et de la
# variete. Un passant qui traverse le champ a la bonne vitesse fait tout le
# travail ; le meme avec une machine a etats en ferait autant pour dix fois
# le prix.
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


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravite * delta

	var cible := arrivee if _vers_arrivee else depart
	var vers := cible - global_position
	vers.y = 0.0

	if vers.length() < 0.6:
		_attente += delta
		if _attente > pause:
			_vers_arrivee = not _vers_arrivee
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
