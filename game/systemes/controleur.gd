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

## Toutes les maisons de la carte. Le controleur cherche la plus proche a
## chaque image : a deux maisons c'est gratuit, et le jour ou il y en aura
## trente on passera par des zones de detection.
@export var maisons: NodePath

## Rectangle noir plein ecran servant au fondu de porte.
@export var fondu: NodePath

## Joue les ambiances. Facultatif : sans lui on entre quand meme, en silence.
@export var audio: NodePath

enum Etat { A_PIED, AU_VOLANT, DEDANS }

var _etat: int = Etat.A_PIED
var _j: Joueur
var _v: Vehicule
var _c: Camera3D
var _invite: Label
var _fondu: ColorRect
var _audio: Audio
var _maisons: Array[Maison] = []

## La maison dans laquelle on se trouve. Nulle des qu'on est dehors.
var _dedans: Maison = null

## Vrai pendant le fondu. Tant qu'il dure, plus aucune commande ne passe :
## sans ce verrou, un appui repete sur F pendant le noir enchaine deux
## transitions et depose le joueur dans le decor.
var _transition: bool = false


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

	_fondu = get_node_or_null(fondu) as ColorRect
	_audio = get_node_or_null(audio) as Audio
	var racine := get_node_or_null(maisons)
	if racine != null:
		for n in racine.get_children():
			if n is Maison:
				_maisons.append(n as Maison)

	_v.quitter_le_volant()
	_c.suivre(_j)
	_c.interieur(false)
	if _fondu != null:
		_fondu.color.a = 0.0
	_afficher("")


func _process(_delta: float) -> void:
	if _transition:
		return

	match _etat:
		Etat.AU_VOLANT:
			_afficher("F   Descendre")
			if Input.is_action_just_pressed("interagir"):
				_descendre()

		Etat.DEDANS:
			var vers_sortie := _j.global_position.distance_to(_dedans.entree())
			var sortable := vers_sortie <= reglages.portee_porte
			_afficher("F   Sortir" if sortable else "")
			if sortable and Input.is_action_just_pressed("interagir"):
				_sortir()

		_:
			_a_pied()


# A pied, deux interactions se disputent la meme touche. On tranche par la
# distance plutot que par un ordre fixe : garer la voiture devant chez soi est
# exactement ce qu'on fera tout le temps, et il faut que F fasse alors la
# chose la plus proche, pas la premiere testee.
func _a_pied() -> void:
	var d_v := _j.global_position.distance_to(_v.global_position)
	var portee_v := reglages.portee_interaction + 1.4

	var maison := _maison_proche()
	var d_m := INF
	if maison != null:
		d_m = _j.global_position.distance_to(maison.seuil())

	if maison != null and d_m <= reglages.portee_porte and d_m < d_v:
		_afficher("F   Entrer chez %s" % maison.nom_affiche)
		if Input.is_action_just_pressed("interagir"):
			_entrer(maison)
		return

	var proche := d_v <= portee_v
	_afficher("F   Monter" if proche else "")
	if proche and Input.is_action_just_pressed("interagir"):
		_monter()


func _maison_proche() -> Maison:
	var meilleure: Maison = null
	var mini := INF
	for m in _maisons:
		var d := _j.global_position.distance_to(m.seuil())
		if d < mini:
			mini = d
			meilleure = m
	return meilleure


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


func _entrer(m: Maison) -> void:
	await _passer_la_porte(m.entree(), m.cap_entree())
	_etat = Etat.DEDANS
	_dedans = m
	_c.interieur(true)
	if _audio != null:
		_audio.ambiance(m.nom_affiche)


func _sortir() -> void:
	var m := _dedans
	await _passer_la_porte(m.seuil(), m.cap_sortie())
	_etat = Etat.A_PIED
	_dedans = null
	_c.interieur(false)
	if _audio != null:
		_audio.ambiance("")


# Noir, on deplace, on rouvre. Le deplacement se fait au creux du fondu :
# c'est la seule image ou le saut de six cents metres est invisible.
func _passer_la_porte(destination: Vector3, cap: float) -> void:
	_transition = true
	_afficher("")
	await _noircir(1.0)

	_j.global_position = destination + Vector3.UP * 0.1
	_j.velocity = Vector3.ZERO
	_j.rotation.y = cap
	# La camera doit sauter avec lui. Sans ce recalage elle rattraperait la
	# distance en lissant, et on verrait defiler le vide entre les deux.
	_c.recaler()
	# Une image complete pour que la physique repose le personnage et que la
	# camera se replace avant qu'on rouvre.
	await get_tree().physics_frame

	await _noircir(0.0)
	_transition = false


func _noircir(alpha: float) -> void:
	if _fondu == null:
		return
	var t := create_tween()
	t.tween_property(_fondu, "color:a", alpha, reglages.fondu_porte)
	await t.finished


func _afficher(texte: String) -> void:
	if _invite != null:
		_invite.text = texte
