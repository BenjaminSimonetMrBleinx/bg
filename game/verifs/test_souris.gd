# Verifie la visee a la souris.
#
#   godot --path game --script res://verifs/test_souris.gd
#
# Le vrai risque n'est pas le calcul d'angle : c'est que l'evenement
# n'arrive jamais. Toute l'interface et la camera vivent dans le SubViewport
# de rendu, ou Godot ne propage aucune entree. C'est ce qui avait rendu la
# roue des outils inutilisable pendant deux jours, sans la moindre erreur.
#
# Ce test envoie donc un VRAI evenement dans la boucle d'entree du moteur, au
# lieu d'appeler la methode de la camera. Si la chaine se rompt quelque part,
# il le voit.
extends SceneTree

const POSE := 40

var _n := 0
var _etape := 0
var _cam: Camera3D
var _c: Node
var _cap_avant := 0.0
var _tangage_avant := 0.0
var _zoom_avant := 1.0
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


func _bouger(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(dx, dy)
	e.screen_relative = e.relative
	Input.parse_input_event(e)


func _process(_d: float) -> bool:
	_n += 1

	if _etape == 0:
		if _n < POSE:
			return false
		_cam = _trouver(root, "Camera3D") as Camera3D
		_c = _trouver(root, "Controleur")
		if _cam == null or _c == null:
			printerr("noeuds introuvables")
			quit(1)
			return true

		# En headless la capture n'a pas de sens pour le systeme, mais le
		# controleur s'en sert comme condition : on la pose explicitement.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		print("--- l'evenement traverse-t-il jusqu'a la camera ---")
		_cap_avant = _cam.get("_cap")
		_tangage_avant = _cam.get("_tangage")
		_bouger(120.0, 0.0)
		_etape = 1
		return false

	if _etape == 1:
		var cap: float = _cam.get("_cap")
		_verifier(not is_equal_approx(cap, _cap_avant),
				"un mouvement horizontal tourne la camera (%.3f -> %.3f)"
				% [_cap_avant, cap])
		# Le sens compte, et il a ete inverse pendant une journee : la souris
		# vers la droite faisait tourner la vue a gauche.
		#
		# _cap va du sujet VERS la camera, le regard est son oppose, et un
		# lacet positif tourne vers la gauche en Godot. Regarder a droite
		# DIMINUE donc _cap. La premiere version de ce test affirmait
		# l'inverse : il validait le defaut au lieu de l'attraper.
		_verifier(cap < _cap_avant,
				"vers la droite fait tourner la vue a droite")

		_bouger(0.0, -140.0)
		_etape = 2
		return false

	# A partir d'ici, chaque etape ENVOIE et la suivante MESURE.
	#
	# Input.parse_input_event met l'evenement dans la file du moteur : il
	# n'est distribue qu'a la trame suivante. Une premiere version envoyait
	# quarante mouvements puis lisait l'angle dans la meme trame, et
	# concluait que la butee etait a 26 degres — c'etait simplement la
	# valeur d'avant, aucun des quarante n'ayant encore ete traite.
	if _etape == 2:
		var t: float = _cam.get("_tangage")
		_verifier(t > _tangage_avant,
				"monter la souris leve la camera (%.3f)" % t)
		print("--- les butees ---")
		for i in 40:
			_bouger(0.0, -400.0)
		_etape = 3
		return false

	if _etape == 3:
		var haut: float = _cam.get("_tangage")
		_verifier(haut <= deg_to_rad(_cam.reglages.tangage_max) + 0.01,
				"le tangage est borne en haut (%.0f deg)" % rad_to_deg(haut))
		_verifier(haut > deg_to_rad(_cam.reglages.tangage_max) - 5.0,
				"et il atteint bien la butee, sans se bloquer avant")
		for i in 40:
			_bouger(0.0, 400.0)
		_etape = 4
		return false

	if _etape == 4:
		var bas: float = _cam.get("_tangage")
		_verifier(bas >= deg_to_rad(_cam.reglages.tangage_min) - 0.01,
				"et borne en bas (%.0f deg)" % rad_to_deg(bas))
		print("--- la molette ---")
		_zoom_avant = _cam.get("_zoom")
		for i in 30:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_WHEEL_DOWN
			e.pressed = true
			Input.parse_input_event(e)
		_etape = 5
		return false

	if _etape == 5:
		var loin: float = _cam.get("_zoom")
		_verifier(loin > _zoom_avant,
				"la molette eloigne (%.2f -> %.2f)" % [_zoom_avant, loin])
		_verifier(loin <= _cam.reglages.zoom_max + 0.001,
				"sans depasser la butee (%.2f)" % loin)

		# Apres un mouvement de souris, la camera ne doit PAS ramener
		# immediatement : sinon regarder de cote en marchant est impossible,
		# ce qui est tout l'interet de la visee libre.
		print("--- le recentrage automatique attend ---")
		_verifier(float(_cam.get("_manuel")) > 0.0,
				"le recentrage est suspendu apres un mouvement")

		print("")
		if _erreurs.is_empty():
			print("TEST SOURIS OK")
			quit(0)
		else:
			printerr("TEST SOURIS ECHOUE : %d probleme(s)" % _erreurs.size())
			quit(1)
		return true

	return false
