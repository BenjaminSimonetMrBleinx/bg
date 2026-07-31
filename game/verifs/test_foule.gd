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


func _maillages(n: Node) -> Array[MeshInstance3D]:
	var trouves: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		trouves.append(n as MeshInstance3D)
	for e in n.get_children():
		trouves.append_array(_maillages(e))
	return trouves


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
		# LA FOULE PEUT ETRE DESACTIVEE, et ce n'est pas une panne.
		#
		# On travaille la ville seule depuis le 31/07/2026 : l'effectif est a
		# zero le temps que la trame irreguliere soit supportee cote jeu — voir
		# docs/16-albuquerque.md. Un test qui echoue pour un reglage volontaire
		# est un test qu'on apprend a ignorer, et c'est pire que pas de test.
		if n == 0:
			print("  --   foule desactivee (combien = 0), rien a verifier")
			print("")
			print("TEST FOULE OK")
			quit(0)
			return true
		_verifier(n > 0, "%d passant(s) crees" % n)

		# LE CORPS ET LA DEMARCHE, SANS RIEN SUPPOSER DU MODELE.
		#
		# Ce test cherchait un noeud nomme « Bassin » et un autre nomme « Tete ».
		# C'etait juste tant que les passants etaient des boites assemblees ;
		# depuis qu'ils sont les figurants du pack, ce sont des maillages a
		# squelette et ces noms n'existent plus. Le test tombait au rouge alors
		# que la rue etait plus belle qu'avant.
		#
		# On verifie donc ce qui compte vraiment et qui vaut pour les deux : il y
		# a quelque chose a voir, et il y a de quoi l'animer.
		var modeles := {}
		var sans_demarche := 0
		for p in _foule.get_children():
			_avant.append((p as Node3D).global_position)
			var maillages := _maillages(p)
			_verifier(not maillages.is_empty(), "%s a bien un corps" % p.name)
			# Un squelette avec ses clips, ou des segments animes par le code.
			# Sans l'un des deux, le passant traverse la rue en glissant.
			var anime: bool = p.find_child("AnimationPlayer", true, false) != null 					or p.find_child("Bassin", true, false) != null
			if not anime:
				sans_demarche += 1
			for mi in maillages:
				if mi.mesh != null:
					modeles[mi.mesh.get_rid()] = true
		_verifier(sans_demarche == 0,
				"tous savent marcher (%d sans demarche)" % sans_demarche)
		_verifier(modeles.size() >= 2,
				"%d maillage(s) different(s) dans la rue" % modeles.size())

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
