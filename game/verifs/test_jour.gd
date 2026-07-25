# Verifie que le moment de la journee est applique PARTOUT.
#
#   godot --headless --path game --script res://verifs/test_jour.gd
#
# Le moment est cuit dans les textures et relu par cinq systemes. Une bascule
# a moitie faite ne plante pas : elle donne un ciel de midi sur des fenetres
# allumees, ou une ville de nuit avec un soleil. Personne ne sait alors lequel
# des deux a tort, et on cherche dans le mauvais fichier.
extends SceneTree

const POSE := 45

var _n := 0
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

	var jour := Reglages.est_jour()
	print("--- moment : %s ---" % ("jour" if jour else "nuit"))

	# La source de verite est le fichier, pas une constante du code.
	_verifier(FileAccess.file_exists(Reglages.MONDE),
			"donnees/monde.json existe")

	var lampes := _trouver(root, "Lampes")
	var soleil := _trouver(root, "Soleil")
	var vehicule := _trouver(root, "Vehicule")
	var phare := _trouver(vehicule, "PhareG") as SpotLight3D
	var maison = _trouver(root, "Maisons").get_child(0)
	var porche := maison.find_child("Porche", false, false)

	var n_lampes := lampes.get_child_count() if lampes != null else 0
	print("       lampadaires allumes : %d" % n_lampes)
	print("       soleil              : %s" % ("oui" if soleil != null else "non"))
	print("       phares visibles     : %s" % ("oui" if phare != null and phare.visible else "non"))
	print("       lumiere de porche   : %s" % ("oui" if porche != null else "non"))

	if jour:
		# Chaque source coute meme quand elle n'eclaire rien : de jour on ne
		# les cree pas du tout, plutot que de les eteindre.
		_verifier(n_lampes == 0, "aucun lampadaire de jour")
		_verifier(soleil != null, "il y a un soleil")
		_verifier(phare != null and not phare.visible, "les phares sont eteints")
		_verifier(porche == null, "pas de lumiere de porche de jour")
	else:
		_verifier(n_lampes > 0, "les lampadaires sont allumes")
		_verifier(soleil == null, "aucun soleil la nuit")
		_verifier(porche != null, "la porte est eclairee")

	# Le brouillard ne doit jamais avaler tout le ciel de jour : a 1, on
	# obtient un aplat gris pale au lieu du bleu d'Albuquerque.
	var env := (_trouver(root, "Environnement") as WorldEnvironment).environment
	print("       brume sur le ciel   : %.2f" % env.fog_sky_affect)
	if jour:
		_verifier(env.fog_sky_affect < 0.8, "le ciel garde sa couleur")
		_verifier(env.fog_depth_end > 150.0,
				"on voit loin (%.0f m)" % env.fog_depth_end)

	print("")
	if _erreurs.is_empty():
		print("TEST JOUR OK")
		quit(0)
	else:
		printerr("TEST JOUR ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
