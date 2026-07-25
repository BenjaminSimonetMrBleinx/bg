# Verifie que le personnage se stabilise dans les quatre directions.
#
#   godot --path game --script res://outils/test_camera.gd
#
# Les touches sont simulees et le jeu tourne normalement : c'est la boucle
# complete camera <-> personnage qui est mise a l'epreuve, pas des fonctions
# prises isolement.
#
# Ecrit apres deux bugs de la meme famille. Le personnage calcule ses
# deplacements par rapport a la camera, et la camera se place par rapport au
# personnage : les deux se poursuivent. Avancer converge par hasard, les
# trois autres directions n'ont aucun point d'equilibre et le font tourner
# indefiniment. Un test qui ne verifierait qu'"avancer" laisserait passer les
# trois quarts du probleme.
extends SceneTree

const POSE := 40          # le temps que tout se pose
const STABILISATION := 260  # le temps de faire son demi-tour et de filer droit
const MESURE := 90        # fenetre d'observation
const DERIVE_MAX := 20.0  # degres tolerés sur la fenetre
const CADRAGE_MAX := 35.0 # ecart tolere entre l'axe du personnage et la camera

const CAS := [
	{"nom": "avancer", "action": "gaz"},
	{"nom": "reculer", "action": "frein"},
	{"nom": "aller a gauche", "action": "gauche"},
	{"nom": "aller a droite", "action": "droite"},
]

var _j: Node3D
var _cam: Camera3D
var _n := 0
var _cas := 0
var _phase := 0
var _debut_angle := 0.0
var _debut_pos := Vector3.ZERO
var _erreurs: Array[String] = []


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	if _j == null:
		_j = _trouver(root, "Joueur") as Node3D
		_cam = _trouver(root, "Camera3D") as Camera3D
		if _j == null or _cam == null:
			printerr("Joueur introuvable")
			quit(1)
			return true
		_lancer_cas()
		return false

	_phase += 1

	if _phase == STABILISATION:
		_debut_angle = _j.rotation.y
		_debut_pos = _j.global_position
	elif _phase >= STABILISATION + MESURE:
		var derive := rad_to_deg(absf(angle_difference(_debut_angle, _j.rotation.y)))
		var parcouru := _j.global_position.distance_to(_debut_pos)
		var nom: String = CAS[_cas]["nom"]

		# La camera doit avoir fini derriere lui, quelle que soit la direction
		# prise. C'est ce qui manquait : elle ne se replacait qu'en avancant,
		# et il fallait donner un coup d'avance pour la remettre en place
		# apres etre alle sur le cote.
		var vers_camera := _cam.global_position - _j.global_position
		vers_camera.y = 0.0
		var avant := -_j.global_transform.basis.z
		avant.y = 0.0
		var ecart := rad_to_deg(absf(avant.normalized().angle_to(
				-vers_camera.normalized())))

		# Sans ce controle, une derive nulle voudrait simplement dire que le
		# personnage n'a pas bouge — le test passerait pour la mauvaise raison.
		if parcouru < 1.0:
			_erreurs.append(nom + " (immobile)")
			printerr("  ECHEC %-16s n'a pas bouge (%.2f m) : bloque en %s"
					% [nom, parcouru, _j.global_position])
		elif derive >= DERIVE_MAX:
			_erreurs.append(nom)
			printerr("  ECHEC %-16s tourne sans fin (derive %.1f deg sur 1,5 s)"
					% [nom, derive])
		elif ecart > CADRAGE_MAX:
			_erreurs.append(nom + " (camera mal placee)")
			printerr("  ECHEC %-16s la camera est restee de cote (%.0f deg "
					% [nom, ecart] + "de l'axe du personnage)")
		else:
			print("  ok   %-16s %.1f m, derive %.1f deg, camera a %.0f deg de l'axe"
					% [nom, parcouru, derive, ecart])
		Input.action_release(CAS[_cas]["action"])
		_cas += 1
		if _cas >= CAS.size():
			return _conclure()
		_lancer_cas()

	return false


## Chaque cas repart du desert, hors de la ville : sol plat, aucun obstacle
## sur des dizaines de metres.
##
## Deux versions precedentes partaient de la chaussee et concluaient a tort
## que le personnage ne bougeait pas — il butait en realite contre la voiture,
## puis contre un immeuble apres avoir traverse un trottoir. Un test de
## stabilite ne doit rien avoir a heurter, sinon il mesure la collision.
const DEPART := Vector3(-60.0, 0.6, 60.0)


func _lancer_cas() -> void:
	_phase = 0
	_j.global_position = DEPART
	_j.rotation.y = 0.0
	if _j is CharacterBody3D:
		(_j as CharacterBody3D).velocity = Vector3.ZERO
	Input.action_press(CAS[_cas]["action"])


func _conclure() -> bool:
	print("")
	if _erreurs.is_empty():
		print("TEST CAMERA OK")
		quit(0)
	else:
		printerr("TEST CAMERA ECHOUE : %s" % ", ".join(_erreurs))
		quit(1)
	return true


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
