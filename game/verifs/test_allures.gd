# Les trois allures de Walter.
#
#   godot --path game --script res://verifs/test_allures.gd
#
# Trot par defaut, course en maintenant Maj, marche a l'interieur. Trois
# allures qui jouent toutes le meme clip a la meme vitesse ressemblent
# exactement a trois allures qui marchent : on mesure donc l'allure CHOISIE, le
# clip joue, et la distance reellement parcourue.
extends SceneTree

const POSE := 30

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _joueur: Joueur


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


# Combien de metres en une seconde, dans la situation demandee.
func _parcourir(sprint: bool, dedans: bool) -> float:
	_joueur.interieur = dedans
		# Au MILIEU de la chaussee, et pas au point de depart : l'Alpine y est
	# garee depuis qu'elle a son lieu nomme, et le joueur demarrait dedans. Il
	# glissait alors contre elle, ce qui donnait exactement la meme distance
	# aux trois allures — un resultat parfaitement stable et parfaitement faux.
	_joueur.global_position = Vector3(8.5, 0.4, -30.0)
	_joueur.rotation = Vector3.ZERO
	_joueur.velocity = Vector3.ZERO
	for i in 12:
		await physics_frame
	var depart := _joueur.global_position
	if sprint:
		Input.action_press("sprint")
	Input.action_press("gaz")
	for i in 60:
		await physics_frame
	Input.action_release("gaz")
	if sprint:
		Input.action_release("sprint")
	return _joueur.global_position.distance_to(depart)


func _scenario() -> void:
	# Sans trafic : une voiture qui vient percuter le joueur pendant la mesure
	# fausse la distance sans rien dire.
	var trafic := _trouver(_monde, "Trafic")
	if trafic != null:
		trafic.free()
	_joueur = _trouver(_monde, "Joueur") as Joueur
	if _joueur == null:
		printerr("  ECHEC Joueur introuvable")
		quit(1)
		return

	var reglages := ResourceLoader.load("res://systemes/reglages.tres") as Reglages

	print("\n--- dehors, sans rien : il trottine ---")
	var d_trot := await _parcourir(false, false)
	print("       %.2f m en 1 s, allure '%s', animation '%s'"
			% [d_trot, _joueur.allure(), _joueur.animation()])
	_verifier(_joueur.allure() == "trot", "l'allure par defaut est le trot")
	_verifier(_joueur.animation() != "", "une animation tourne")

	print("\n--- Maj enfoncee : il court ---")
	var d_course := await _parcourir(true, false)
	print("       %.2f m en 1 s, allure '%s', animation '%s'"
			% [d_course, _joueur.allure(), _joueur.animation()])
	_verifier(_joueur.allure() == "course", "Maj passe a la course")
	_verifier(d_course > d_trot * 1.25,
			"il va nettement plus vite (%.2f m contre %.2f)" % [d_course, d_trot])

	print("\n--- a l'interieur : il marche ---")
	var d_marche := await _parcourir(false, true)
	print("       %.2f m en 1 s, allure '%s', animation '%s'"
			% [d_marche, _joueur.allure(), _joueur.animation()])
	_verifier(_joueur.allure() == "marche", "dedans, il marche")
	_verifier(d_marche < d_trot * 0.9,
			"et plus lentement (%.2f m contre %.2f)" % [d_marche, d_trot])
	# La marche doit jouer un AUTRE clip que la course. C'est le seul des trois
	# controles qui verifie que l'animation suit l'allure et pas seulement la
	# vitesse — sans lui, trois vitesses sur un seul clip passeraient au vert.
	_verifier(_joueur.animation() == Demarche.CYCLE,
			"et sur le clip de marche ('%s')" % _joueur.animation())

	# Maj a l'interieur ne doit RIEN faire : courir dans un salon de sept
	# metres n'a pas de sens, et le laisser faire donne un personnage qui
	# traverse la piece en deux images.
	print("\n--- Maj a l'interieur ne change rien ---")
	var d_dedans_sprint := await _parcourir(true, true)
	_verifier(_joueur.allure() == "marche", "on marche toujours")
	_verifier(absf(d_dedans_sprint - d_marche) < 0.4,
			"et a la meme vitesse (%.2f contre %.2f)"
					% [d_dedans_sprint, d_marche])

	print("")
	if _erreurs.is_empty():
		print("TEST ALLURES OK")
		quit(0)
	else:
		printerr("TEST ALLURES ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
