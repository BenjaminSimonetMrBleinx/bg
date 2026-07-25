# Verifie que la voiture roule DROIT et prend ses tours.
#
#   godot --path game --script res://outils/test_conduite.gd
#
# Ecrit apres un defaut signale au clavier : « en accelerant elle se dandine
# et fait des gauche-droite, ca la ralentit aussi ». Deux symptomes, une
# seule cause profonde — des reglages dans la mauvaise unite.
#
# wheel_friction_slip n'est PAS un coefficient entre 0 et 1 : sa valeur
# normale dans Godot est 10,5. A 0,85 on roule sur de la glace, l'arriere
# chasse, se rattrape, rechasse — c'est le dandinement — et les roues
# patinent au lieu d'entrainer, d'ou la reprise molle.
#
# On mesure donc l'ecart lateral a une trajectoire droite, la derive de cap,
# et la vitesse atteinte. Aucun de ces trois ne se juge a l'oeil sur une
# capture.
extends SceneTree

const POSE := 40
const ROULAGE := 460

const ECART_MAX := 1.2      # metres de derive laterale toleres
const LACET_MAX := 6.0      # degres de derive de cap toleres
const VITESSE_MIN := 45.0   # km/h attendus apres l'acceleration

var _n := 0
var _c: Node
var _v: VehicleBody3D
var _depart := Vector3.ZERO
var _axe := Vector3.ZERO
var _cap_depart := 0.0
var _ecart_max := 0.0
var _erreurs: Array[String] = []


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _verifier(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   " + msg)
	else:
		_erreurs.append(msg)
		printerr("  ECHEC " + msg)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	if _c == null:
		_c = _trouver(root, "Controleur")
		_v = _trouver(root, "Vehicule") as VehicleBody3D
		if _c == null or _v == null:
			printerr("noeuds introuvables")
			quit(1)
			return true
		_c.call("_monter")
		# En plein desert : aucun trottoir, aucun mobilier, rien a heurter.
		# Un test de trajectoire qui percute quelque chose mesure la collision.
		_v.global_position = Vector3(-60.0, 0.6, 60.0)
		_v.linear_velocity = Vector3.ZERO
		_v.angular_velocity = Vector3.ZERO
		_depart = _v.global_position
		_axe = -_v.global_transform.basis.z
		_axe.y = 0.0
		_axe = _axe.normalized()
		_cap_depart = _v.rotation.y
		print("--- plein gaz, tout droit, aucune commande de direction ---")
		return false

	# On pousse comme une touche maintenue, sans jamais braquer.
	_v.call("_propulser", 1.0, _v.call("vitesse_kmh"))

	if _n > POSE + 40:
		var vers: Vector3 = _v.global_position - _depart
		vers.y = 0.0
		# Distance a la droite ideale : la composante perpendiculaire a l'axe
		# de depart. C'est la mesure du dandinement.
		var lateral := (vers - _axe * vers.dot(_axe)).length()
		_ecart_max = maxf(_ecart_max, lateral)

	if _n < POSE + ROULAGE:
		return false

	var kmh: float = _v.call("vitesse_kmh")
	var parcouru: float = _depart.distance_to(_v.global_position)
	var lacet := rad_to_deg(absf(angle_difference(_cap_depart, _v.rotation.y)))

	print("       distance parcourue   %.1f m" % parcouru)
	print("       vitesse atteinte     %.1f km/h" % kmh)
	print("       ecart lateral max    %.2f m" % _ecart_max)
	print("       derive de cap        %.1f deg" % lacet)

	_verifier(parcouru > 10.0, "elle avance (%.1f m)" % parcouru)
	_verifier(_ecart_max < ECART_MAX,
			"elle roule droit (%.2f m d'ecart, seuil %.1f)" % [_ecart_max, ECART_MAX])
	_verifier(lacet < LACET_MAX,
			"elle ne se dandine pas (%.1f deg, seuil %.0f)" % [lacet, LACET_MAX])
	_verifier(kmh > VITESSE_MIN,
			"elle prend ses tours (%.0f km/h, seuil %.0f)" % [kmh, VITESSE_MIN])

	print("")
	if _erreurs.is_empty():
		print("TEST CONDUITE OK")
		quit(0)
	else:
		printerr("TEST CONDUITE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
