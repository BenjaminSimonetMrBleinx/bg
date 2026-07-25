# Bascule entre marcher et conduire.
#
# Un seul endroit decide qui recoit les commandes, qui la camera suit, et ce
# que l'invite affiche. Sans ce point unique, l'etat se disperse dans trois
# scripts et finit par se contredire — le personnage qui marche encore alors
# qu'on roule, la camera qui suit le mauvais sujet.
extends Node

@export var reglages: Reglages
@export var joueur: NodePath
@export var vehicule: NodePath
@export var camera: NodePath
@export var invite: NodePath

enum Etat { A_PIED, AU_VOLANT }

var _etat: int = Etat.A_PIED
var _j: Joueur
var _v: Vehicule
var _c: Camera3D
var _invite: Label


func _ready() -> void:
	_j = get_node_or_null(joueur) as Joueur
	_v = get_node_or_null(vehicule) as Vehicule
	_c = get_node_or_null(camera) as Camera3D
	_invite = get_node_or_null(invite) as Label

	for n in [["joueur", _j], ["vehicule", _v], ["camera", _c]]:
		if n[1] == null:
			push_error("controleur : %s introuvable" % n[0])
			set_process(false)
			return

	_v.quitter_le_volant()
	_c.suivre(_j)
	_afficher("")


func _process(_delta: float) -> void:
	if _etat == Etat.A_PIED:
		var d := _j.global_position.distance_to(_v.global_position)
		var proche := d <= reglages.portee_interaction + 1.4
		_afficher("F   Monter" if proche else "")
		if proche and Input.is_action_just_pressed("interagir"):
			_monter()
	else:
		_afficher("F   Descendre")
		if Input.is_action_just_pressed("interagir"):
			_descendre()


func _monter() -> void:
	_etat = Etat.AU_VOLANT
	_j.set_physics_process(false)
	_j.visible = false
	# La capsule doit disparaitre du monde physique, sinon la voiture bute
	# dedans en demarrant.
	_j.process_mode = Node.PROCESS_MODE_DISABLED
	_v.prendre_le_volant()
	_c.suivre(_v)


func _descendre() -> void:
	_etat = Etat.A_PIED
	_v.quitter_le_volant()

	# On repose Walter a la portiere conducteur, dans le repere du vehicule :
	# il sort du bon cote quel que soit le sens de la voiture.
	var marque := _v.get_node_or_null("SortieConducteur") as Node3D
	var pos := marque.global_position if marque != null else \
			_v.global_position - _v.global_transform.basis.x * 1.7
	pos.y = _v.global_position.y + 0.1

	_j.process_mode = Node.PROCESS_MODE_INHERIT
	_j.global_position = pos
	_j.velocity = Vector3.ZERO
	# Il regarde dans le meme sens que la voiture, ce qui evite un demi-tour
	# desagreable des le premier appui sur une touche.
	_j.rotation.y = _v.rotation.y
	_j.visible = true
	_j.set_physics_process(true)
	_c.suivre(_j)


func _afficher(texte: String) -> void:
	if _invite != null:
		_invite.text = texte
