# Verifie que les commandes deplacent le vehicule dans le bon sens.
#
#   godot --path game --script res://verifs/test_sens.gd
#
# Ecrit pour trancher empiriquement une question de convention plutot que de
# la deduire de la documentation — et garde ensuite comme non-regression : le
# VehicleBody3D de Godot pousse vers +Z alors que le nez pointe vers -Z, et
# c'est exactement le genre de piege qui revient a la premiere refonte.
#
# Sort en 0 si avancer avance, en 1 sinon.
extends SceneTree

const IMAGES_POSE := 40      # le temps que la caisse se pose sur ses roues
const IMAGES_TEST := 150

var _vehicule: Node
var _depart: Vector3
var _nez: Vector3
var _n := 0


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _process(_d: float) -> bool:
	_n += 1

	if _n == IMAGES_POSE:
		_vehicule = _chercher(root)
		if _vehicule == null:
			printerr("aucun VehicleBody3D trouve")
			quit(1)
			return true
		_depart = _vehicule.global_position
		_nez = -_vehicule.global_transform.basis.z

	if _n > IMAGES_POSE and _vehicule != null:
		# On appelle la logique du controleur avec une commande d'avance
		# franche, sans passer par le clavier.
		_vehicule.call("_propulser", 1.0, _vehicule.call("vitesse_kmh"))
		_vehicule.steering = 0.0

	if _n < IMAGES_TEST:
		return false

	var delta: Vector3 = _vehicule.global_position - _depart
	var projection := delta.dot(_nez)
	print("nez           %s" % _nez)
	print("deplacement   %s  (%.2f m)" % [delta, delta.length()])
	print("projection    %.3f m sur le nez" % projection)
	print("")
	if projection > 0.5:
		print("OK : la commande d'avance fait avancer (%.2f m)" % projection)
		quit(0)
	elif projection < -0.5:
		printerr("ECHEC : la commande d'avance fait RECULER (%.2f m)" % projection)
		quit(1)
	else:
		printerr("ECHEC : le vehicule n'a pas bouge de facon exploitable")
		quit(1)
	return true


func _chercher(n: Node) -> Node:
	if n is VehicleBody3D:
		return n
	for e in n.get_children():
		var t := _chercher(e)
		if t != null:
			return t
	return null
