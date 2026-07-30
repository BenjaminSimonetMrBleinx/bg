# Verifie que les passants marchent vraiment.
#
#   godot --headless --path game --script res://verifs/test_foule.gd
#
# Un passant coince contre une poubelle a l'air parfaitement normal sur une
# capture : il est debout, au bon endroit, correctement texture. Il ne bouge
# simplement jamais. La seule facon de le voir est de mesurer un deplacement
# entre deux instants.
extends SceneTree

# Doivent correspondre a outils/gen_ville.py.
const PAS := 54.0
const TROTTOIR := 3.0
const ROUTE := 8.0

const POSE := 30
const MARCHE := 110          # environ deux secondes

var _n := 0
var _etape := 0
var _foule: Node
var _avant: Array[Vector3] = []
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


func _sur_chaussee(v: float) -> bool:
	var dans := fposmod(v, PAS)
	return dans > TROTTOIR and dans < TROTTOIR + ROUTE


func _process(_d: float) -> bool:
	_n += 1

	if _etape == 0:
		if _n < POSE:
			return false
		_foule = _trouver(root, "Foule")
		if _foule == null:
			printerr("noeud Foule introuvable")
			quit(1)
			return true

		var n := _foule.get_child_count()
		print("--- les passants ---")
		_verifier(n > 0, "%d passant(s) crees" % n)

		var modeles := {}
		for p in _foule.get_children():
			_avant.append((p as Node3D).global_position)
			# Le maillage doit etre la : un passant sans segments marche
			# quand meme, invisible, et rien ne le signale.
			_verifier(p.find_child("Bassin", true, false) != null,
					"%s a bien un corps" % p.name)
			var tete := p.find_child("Tete", true, false) as MeshInstance3D
			if tete != null and tete.mesh != null and tete.mesh.get_surface_count() > 0:
				modeles[tete.mesh.surface_get_material(0).resource_name] = true
		_verifier(modeles.size() >= 2,
				"%d apparences differentes dans la rue" % modeles.size())

		_etape = 1
		_n = 0
		return false

	if _n < MARCHE:
		return false

	print("--- deux secondes plus tard ---")
	var immobiles := 0
	var hors_trottoir := 0
	var tombes := 0
	var parcours := 0.0

	for i in _foule.get_child_count():
		var p := _foule.get_child(i) as Node3D
		# ON MESURE CE QUI A ETE MARCHE, PAS L'ECART ENTRE DEUX POSITIONS.
		#
		# La foule se recycle autour du joueur depuis le 30/07/2026 : un passant
		# trop loin est repose sur une rue proche. Comparer deux positions
		# compterait ce saut comme cent metres de marche, et un passant coince
		# contre une poubelle juste apres avoir ete replace passerait pour le
		# plus actif de la rue.
		var d: float = (p as Pieton).parcouru if p is Pieton \
				else _avant[i].distance_to(p.global_position)
		parcours += d
		if d < 0.4:
			immobiles += 1
			printerr("       %s n'a pas bouge (%s)" % [p.name, str(p.global_position.round())])
		if p.global_position.y < 0.05:
			tombes += 1
		if _sur_chaussee(p.global_position.x) and _sur_chaussee(-p.global_position.z):
			hors_trottoir += 1

	print("       distance moyenne parcourue : %.2f m"
			% (parcours / maxf(1.0, _foule.get_child_count())))
	_verifier(immobiles == 0, "aucun passant coince (%d)" % immobiles)
	_verifier(tombes == 0, "aucun n'est passe sous la carte (%d)" % tombes)
	_verifier(hors_trottoir == 0,
			"aucun ne marche au milieu d'un carrefour (%d)" % hors_trottoir)

	print("")
	if _erreurs.is_empty():
		print("TEST FOULE OK")
		quit(0)
	else:
		printerr("TEST FOULE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
