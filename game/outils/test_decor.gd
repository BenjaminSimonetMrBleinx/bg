# Verifie le mobilier urbain et les jardins.
#
#   godot --headless --path game --script res://outils/test_decor.gd
#
# Le decor est place par un generateur et instancie au lancement : personne
# ne le regarde poser. Une poubelle au milieu de la chaussee ne provoque
# aucune erreur — elle attend juste qu'on lui rentre dedans a quarante.
extends SceneTree

# Doivent correspondre a outils/gen_ville.py. Si la ville change de gabarit
# et pas ce test, il validera une geometrie qui n'existe plus.
const PAS := 54.0
const TROTTOIR := 3.0
const ROUTE := 8.0

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


# Vrai si la coordonnee tombe sur une chaussee. Les couloirs se repetent tous
# les PAS metres, la chaussee occupant le milieu du couloir.
func _sur_chaussee(v: float) -> bool:
	var dans := fposmod(v, PAS)
	return dans > TROTTOIR and dans < TROTTOIR + ROUTE


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	var decor := _trouver(root, "Decor")
	var joueur := _trouver(root, "Joueur") as Node3D
	var vehicule := _trouver(root, "Vehicule") as Node3D
	if decor == null or joueur == null or vehicule == null:
		printerr("noeuds introuvables (decor/joueur/vehicule)")
		quit(1)
		return true

	print("--- mobilier urbain ---")
	var elements := decor.get_children()
	_verifier(elements.size() > 20, "%d elements poses" % elements.size())

	# Les noms sont de la forme "poubelle_004". Un nom auto-genere par Godot
	# ("@Node3D@35") signalerait que le poseur ne nomme plus ce qu'il pose,
	# et l'arbre redeviendrait illisible sans que rien ne casse.
	var types := {}
	var anonymes := 0
	for e in elements:
		var nom := str(e.name)
		if nom.begins_with("@"):
			anonymes += 1
			continue
		types[nom.substr(0, nom.rfind("_"))] = 1 + int(
				types.get(nom.substr(0, nom.rfind("_")), 0))
	for t in types:
		print("       %-16s %d" % [t, types[t]])
	_verifier(anonymes == 0, "tous les elements sont nommes (%d anonymes)" % anonymes)
	_verifier(types.size() >= 4, "%d types differents" % types.size())

	print("--- rien sur la chaussee ---")
	var fautifs := 0
	var pire := ""
	for e in elements:
		var p: Vector3 = (e as Node3D).global_position
		# Le decor du desert est hors grille : la formule modulo n'y veut
		# rien dire, on ne teste que ce qui est dans la ville.
		if p.x < -2.0 or p.x > 124.0 or p.z > 2.0 or p.z < -124.0:
			continue
		if _sur_chaussee(p.x) and _sur_chaussee(-p.z):
			fautifs += 1
			pire = "%s en %s" % [e.name, str(p.round())]
	_verifier(fautifs == 0,
			"aucun element au milieu d'un carrefour%s"
			% ("" if fautifs == 0 else " — %d, dont %s" % [fautifs, pire]))

	print("--- rien qui coince le depart ---")
	for cible in [["joueur", joueur], ["vehicule", vehicule]]:
		var mini := INF
		var proche := ""
		for e in elements:
			var d: float = (e as Node3D).global_position.distance_to(
					(cible[1] as Node3D).global_position)
			if d < mini:
				mini = d
				proche = str(e.name)
		print("       %-10s element le plus proche : %s a %.1f m"
				% [cible[0], proche, mini])
		_verifier(mini > 1.6,
				"le %s ne demarre pas dans un objet" % cible[0])

	print("--- jardins des maisons ---")
	var maisons := _trouver(root, "Maisons")
	for m in maisons.get_children():
		var jardin := m.find_child("Jardin", false, false)
		_verifier(jardin != null and jardin.get_child_count() > 0,
				"%s a du decor devant chez elle (%d)"
				% [m.nom_affiche, jardin.get_child_count() if jardin else 0])
		if jardin == null:
			continue
		# Le mobilier de jardin doit rester DEVANT la maison, cote rue : pose
		# derriere, il serait invisible et donnerait une maison nue.
		for o in jardin.get_children():
			var rel: Vector3 = (o as Node3D).position
			_verifier(rel.z > 0.0,
					"%s : '%s' est bien cote rue" % [m.nom_affiche, o.name])

	print("")
	if _erreurs.is_empty():
		print("TEST DECOR OK")
		quit(0)
	else:
		printerr("TEST DECOR ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
