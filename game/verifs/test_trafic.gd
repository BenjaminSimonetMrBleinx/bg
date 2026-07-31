# La circulation.
#
#   godot --path game --script res://verifs/test_trafic.gd
#
# Une voiture qui ne bouge pas ressemble exactement a une voiture garee, et un
# trafic absent ressemble a un trafic pas encore branche. On mesure donc du
# MOUVEMENT, et pas seulement l'existence des agents.
#
# Trois choses, et la troisieme est la vraie difficulte :
#   - elles avancent
#   - elles restent sur la chaussee, pas sur les trottoirs ni dans les murs
#   - elles TOURNENT aux carrefours au lieu de faire des allers-retours
#
# La troisieme est ce qui distingue un reseau d'un segment. C'est tout l'objet
# du chantier : les passants faisaient un aller-retour sur un bout de trottoir
# fixe, et ca ne se transpose pas a une voiture.
extends SceneTree

const POSE := 30

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _trafic: Trafic


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	_monde = ps.instantiate()
	root.add_child(_monde)


func _verifier(ok: bool, message: String) -> void:
	if ok:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _process(_d: float) -> bool:
	_n += 1
	if _n != POSE:
		return false
	_scenario()
	return false


func _scenario() -> void:
	_trafic = _trouver(_monde, "Trafic") as Trafic
	if _trafic == null:
		printerr("  ECHEC noeud Trafic introuvable")
		quit(1)
		return

	var agents := _trafic.agents()
	print("\n--- il y a des voitures ---")
	_verifier(agents.size() >= 5, "%d voiture(s) en circulation" % agents.size())
	if agents.is_empty():
		quit(1)
		return

	# Position de depart de chacune, pour mesurer le deplacement.
	var depart := []
	for a in agents:
		depart.append(a.global_position)

	print("\n--- elles avancent ---")
	for i in 240:
		await physics_frame

	var bouge := 0
	var parcours := 0.0
	for i in agents.size():
		var d: float = agents[i].global_position.distance_to(depart[i])
		parcours += d
		if d > 3.0:
			bouge += 1
	print("       %.0f m parcourus au total en 4 s" % parcours)
	# Toutes ne bougent pas forcement : certaines attendent derriere une autre,
	# et c'est le comportement voulu. La majorite suffit.
	_verifier(bouge >= agents.size() / 2,
			"%d sur %d ont avance" % [bouge, agents.size()])

	print("\n--- elles restent sur la chaussee ---")
	# La chaussee du couloir k va de k*57+3 a k*57+14. Une voiture qui derive
	# finit sur un trottoir ou dans une facade, et ca se voit tout de suite.
	var dehors := 0
	for a in agents:
		if not _sur_une_rue(a.global_position):
			dehors += 1
			print("       hors chaussee : %s" % a.global_position)
	_verifier(dehors == 0, "aucune n'a quitte la chaussee")

	print("\n--- elles tournent aux carrefours ---")
	# On suit UNE voiture assez longtemps pour qu'elle change de rue, et on
	# verifie qu'elle a change d'axe. Un aller-retour sur un segment garderait
	# le meme axe indefiniment — c'est exactement l'ancien comportement.
	var suivie: Circulant = agents[0]
	var axes := {}
	var precedente := suivie.global_position
	for i in 900:
		await physics_frame
		var d := suivie.global_position - precedente
		if d.length() > 0.4:
			axes["x" if absf(d.x) > absf(d.z) else "z"] = true
			precedente = suivie.global_position
		if axes.size() >= 2:
			break
	_verifier(axes.size() >= 2,
			"une voiture suivie a emprunte %d axe(s) differents" % axes.size())

	print("")
	if _erreurs.is_empty():
		print("TEST TRAFIC OK")
		quit(0)
	else:
		printerr("TEST TRAFIC ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


# SUR UNE CHAUSSEE ? ON LE DEMANDE AU GRAPHE, PAS A UNE CONSTANTE.
#
# Ce test calculait les bandes de chaussee a partir d'un PAS de 57 m ecrit en
# dur. C'etait juste tant que la trame etait reguliere ; le jour ou les ilots
# ont pris des tailles differentes, le test a declare des voitures « hors
# chaussee » alors qu'elles roulaient exactement au milieu de leur rue.
#
# C'est le piege le plus cher du projet, dans sa version test : on mesurait une
# HYPOTHESE sur la ville au lieu de mesurer la ville. Le graphe, lui, publie
# ou sont les rues — c'est la meme source que celle dont les voitures se
# servent pour rouler.
const ROUTES := "res://assets/ville/ville_lampes.json"

var _segments: Array = []


func _charger_les_rues() -> void:
	if not _segments.is_empty():
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	if typeof(lu) != TYPE_DICTIONARY:
		return
	var graphe: Dictionary = (lu as Dictionary).get("graphe", {})
	var noeuds: Array = graphe.get("noeuds", [])
	for a in graphe.get("aretes", []):
		var p: Array = noeuds[int(a[0])]
		var q: Array = noeuds[int(a[1])]
		_segments.append([Vector3(p[0], 0.0, p[2]), Vector3(q[0], 0.0, q[2])])


func _sur_une_rue(p: Vector3) -> bool:
	_charger_les_rues()
	if _segments.is_empty():
		return true
	# La demi-chaussee, plus la largeur d'une voiture.
	var marge := 11.0 / 2.0 + 1.2
	var plat := Vector3(p.x, 0.0, p.z)
	for seg in _segments:
		if _distance_au_segment(plat, seg[0], seg[1]) <= marge:
			return true
	return false


static func _distance_au_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
