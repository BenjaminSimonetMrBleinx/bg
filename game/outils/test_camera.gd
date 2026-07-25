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

# Les commandes sont celles d'un char : gauche et droite PIVOTENT, avant et
# arriere deplacent. Le test verifie donc deux choses differentes selon la
# touche, et c'est le coeur du sujet — une version anterieure exigeait un
# deplacement pour les quatre, ce qui n'a plus de sens.
const CAS := [
	{"nom": "avancer", "action": "gaz", "bouge": true},
	{"nom": "reculer", "action": "frein", "bouge": true},
	{"nom": "pivoter a gauche", "action": "gauche", "bouge": false},
	{"nom": "pivoter a droite", "action": "droite", "bouge": false},
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

		if CAS[_cas]["bouge"]:
			# Avancer et reculer : il se deplace, EN LIGNE DROITE, et la
			# camera reste dans son dos. Une derive nulle sans deplacement
			# ferait passer le test pour la mauvaise raison.
			if parcouru < 1.0:
				_erreurs.append(nom + " (immobile)")
				printerr("  ECHEC %-18s n'a pas bouge (%.2f m) : bloque en %s"
						% [nom, parcouru, _j.global_position])
			elif derive >= DERIVE_MAX:
				_erreurs.append(nom)
				printerr("  ECHEC %-18s tourne sans fin (derive %.1f deg)"
						% [nom, derive])
			elif ecart > CADRAGE_MAX:
				_erreurs.append(nom + " (camera mal placee)")
				printerr("  ECHEC %-18s la camera n'est pas dans son dos (%.0f deg)"
						% [nom, ecart])
			else:
				print("  ok   %-18s %.1f m, derive %.1f deg, camera a %.0f deg"
						% [nom, parcouru, derive, ecart])
		else:
			# Pivoter : il tourne SANS avancer. C'est la demande explicite —
			# appuyer sur gauche ou droite a l'arret le faisait partir en
			# avant, ce qui rendait impossible de simplement se retourner.
			if parcouru > 0.5:
				_erreurs.append(nom + " (il avance)")
				printerr("  ECHEC %-18s se deplace en pivotant (%.2f m)"
						% [nom, parcouru])
			elif derive < 20.0:
				_erreurs.append(nom + " (ne tourne pas)")
				printerr("  ECHEC %-18s ne pivote pas (%.1f deg)" % [nom, derive])
			elif ecart > CADRAGE_MAX:
				_erreurs.append(nom + " (camera mal placee)")
				printerr("  ECHEC %-18s la camera n'a pas suivi le pivot (%.0f deg)"
						% [nom, ecart])
			else:
				print("  ok   %-18s pivote de %.0f deg sans avancer (%.2f m), camera a %.0f deg"
						% [nom, derive, parcouru, ecart])
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
