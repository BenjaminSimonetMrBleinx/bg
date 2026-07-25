# Verifie que le moteur produit reellement du son une fois au volant.
#
#   godot --path game --script res://verifs/test_moteur.gd
#
# Le son du moteur ne demarre qu'en montant dans le vehicule. Un couplage
# rate entre le controleur et l'audio ne se voit pas : le jeu tourne, la
# voiture roule, et il n'y a simplement rien a entendre.
extends SceneTree

const POSE := 60
const ROULAGE := 180

var _n := 0
var _c: Node
var _v: VehicleBody3D
var _m: Node
var _bus := -1
var _crete := -200.0
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


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	if _c == null:
		_c = _trouver(root, "Controleur")
		_v = _trouver(root, "Vehicule") as VehicleBody3D
		_m = _trouver(root, "MoteurAudio")
		_bus = AudioServer.get_bus_index("Effets")
		if _c == null or _v == null or _m == null:
			printerr("noeuds introuvables (controleur/vehicule/moteur)")
			quit(1)
			return true

		print("--- couches ---")
		var lecteurs := 0
		for e in _m.get_children():
			if e is AudioStreamPlayer3D and (e as AudioStreamPlayer3D).stream != null:
				lecteurs += 1
		_verifier(lecteurs >= 3, "%d lecteurs avec un flux assigne" % lecteurs)
		_verifier(_bus >= 0, "bus Effets present")

		print("--- on monte, puis on accelere ---")
		_c.call("_monter")
		return false

	# On pousse le vehicule, comme le ferait une touche maintenue.
	_v.call("_propulser", 1.0, _v.call("vitesse_kmh"))
	if _n > POSE + 30:
		_crete = maxf(_crete, AudioServer.get_bus_peak_volume_left_db(_bus, 0))

	if _n < POSE + ROULAGE:
		return false

	print("--- mesure ---")
	print("       vitesse atteinte  %.1f km/h" % _v.call("vitesse_kmh"))
	print("       crete bus Effets  %.1f dB" % _crete)
	_verifier(_crete > -60.0, "le moteur produit du son au volant")
	if _crete > -60.0 and _crete < -35.0:
		print("       (faible : verifier moteur_volume dans reglages.tres)")

	print("")
	if _erreurs.is_empty():
		print("TEST MOTEUR OK")
		quit(0)
	else:
		printerr("TEST MOTEUR ECHOUE : %d probleme(s)" % _erreurs.size())
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
