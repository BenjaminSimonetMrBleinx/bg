# Rendu hors ecran : ouvre la scene, laisse quelques images se stabiliser,
# enregistre une capture et quitte.
#
#   godot --path game --script res://verifs/capture.gd -- --sortie C:\...\x.png
#
# Sans --headless, volontairement : le pilote de rendu factice de Godot ne
# produit aucune image. Une fenetre s'ouvre donc brievement.
#
# Options :
#   --sortie <chemin>   fichier PNG (defaut : capture.png a cote du projet)
#   --scene <res://...> scene a rendre (defaut : la scene principale)
#   --frames <n>        images attendues avant la capture (defaut : 12)
#   --cam <x,y,z>       place la camera a cette position
#   --vise <x,y,z>      oriente la camera vers ce point
#   --scenario <nom>    joue une situation de donnees/scenarios.json
#
# LES SCENARIOS. Une capture du point de depart ne montre que le point de
# depart. Tout ce qui merite d'etre regarde — la roue ouverte, un appel en
# cours, l'arrivee au desert — demande d'AGIR d'abord. On ecrivait donc un
# script jetable a chaque fois, on le lancait, on le supprimait.
#
# Un scenario est cette suite d'actions, ecrite une fois en donnees et
# rejouable. Voir l'en-tete de donnees/scenarios.json.
extends SceneTree

const SCENARIOS := "res://donnees/scenarios.json"
const MONDE := "res://scenes/monde.tscn"

var _sortie := ""
var _frames_a_attendre := 12
var _n := 0
var _cam_pos := Vector3.INF
var _cam_cible := Vector3.INF
var _etapes: Array = []
var _monde: Node
var _scene_du_scenario := MONDE


func _initialize() -> void:
	var args := _options()
	_sortie = args.get("sortie", "capture.png")
	_frames_a_attendre = int(args.get("frames", "12"))
	if args.has("cam"):
		_cam_pos = _vec(args["cam"])
	if args.has("vise"):
		_cam_cible = _vec(args["vise"])
	if args.has("scenario"):
		_charger_scenario(args["scenario"])

	# LA SCENE PAR DEFAUT EST LE MONDE, PAS LA SCENE D'ENTREE. Elle a longtemps
	# suivi main_scene, ce qui revenait au meme — puis l'ecran-titre est passe
	# devant le monde, et toutes les captures se sont mises a photographier un
	# menu. Rien ne le signalait : le fichier PNG etait bien ecrit, les scenarios
	# se deroulaient dans le vide, et il fallait ouvrir l'image pour le voir.
	# Un scenario qui veut une autre scene la nomme (voir "scene" dans
	# scenarios.json) ; --scene tranche au-dessus de tout.
	var chemin: String = args.get("scene", _scene_du_scenario)
	if chemin == "" or not ResourceLoader.exists(chemin):
		printerr("capture : scene introuvable (%s)" % chemin)
		quit(1)
		return

	var ps := ResourceLoader.load(chemin) as PackedScene
	if ps == null:
		printerr("capture : chargement impossible (%s)" % chemin)
		quit(1)
		return
	_monde = ps.instantiate()
	root.add_child(_monde)


func _charger_scenario(nom: String) -> void:
	if not FileAccess.file_exists(SCENARIOS):
		printerr("capture : %s introuvable" % SCENARIOS)
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIOS))
	if typeof(lu) != TYPE_DICTIONARY:
		printerr("capture : %s illisible. Verifier les virgules." % SCENARIOS)
		return
	var tous: Dictionary = (lu as Dictionary).get("scenarios", {})
	if not tous.has(nom):
		printerr("capture : aucun scenario '%s'. Connus : %s"
				% [nom, ", ".join(tous.keys())])
		return
	var s: Dictionary = tous[nom]
	_etapes = s.get("etapes", [])
	# Presque tous se jouent dans le monde ; ceux qui montrent un ecran, comme le
	# titre, nomment leur scene.
	_scene_du_scenario = str(s.get("scene", MONDE))
	# Le scenario impose sa duree : une sonnerie de deux secondes capturee a la
	# douzieme image ne montre rien, et on croit le mecanisme casse.
	_frames_a_attendre = int(s.get("fin", _frames_a_attendre))
	print("scenario '%s' : %s" % [nom, s.get("quoi", "")])


func _process(_delta: float) -> bool:
	_n += 1
	if _n == 2:
		_placer_camera()
	_jouer_les_etapes()
	if _n < _frames_a_attendre:
		return false

	var img := _image()
	if img == null:
		printerr("capture : aucune image disponible — pilote de rendu factice ?")
		quit(1)
		return true

	var err := img.save_png(_sortie)
	if err != OK:
		printerr("capture : ecriture impossible (%s) erreur %d" % [_sortie, err])
		quit(1)
		return true

	print("capture -> %s  (%d x %d)" % [_sortie, img.get_width(), img.get_height()])
	quit(0)
	return true


# Les etapes du scenario, jouees a l'image qu'elles annoncent.
#
# On compare a l'egalite et non a « depassee » : une etape qui se rejouerait a
# chaque image ensuite maintiendrait une touche enfoncee pour toujours, et le
# scenario suivant heriterait de l'etat.
func _jouer_les_etapes() -> void:
	for e in _etapes:
		if int((e as Dictionary).get("image", -1)) != _n:
			continue
		var etape: Dictionary = e

		if etape.has("placer"):
			var n := _trouver(_monde, str(etape["placer"])) as Node3D
			if n == null:
				printerr("capture : noeud '%s' introuvable" % etape["placer"])
				continue
			var p: Array = etape.get("pos", [0, 0, 0])
			n.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
			if etape.has("cap"):
				n.rotation = Vector3(0.0, deg_to_rad(float(etape["cap"])), 0.0)
			# Une masse lancee qu'on repose garde sa vitesse et derive pendant
			# qu'on attend la capture.
			if n is RigidBody3D:
				(n as RigidBody3D).linear_velocity = Vector3.ZERO
				(n as RigidBody3D).angular_velocity = Vector3.ZERO
			elif n is CharacterBody3D:
				(n as CharacterBody3D).velocity = Vector3.ZERO

		if etape.has("lancer"):
			var n := _trouver(_monde, str(etape["lancer"])) as Node3D
			var v: Array = etape.get("vitesse", [0, 0, 0])
			if n is RigidBody3D:
				(n as RigidBody3D).linear_velocity = Vector3(
						float(v[0]), float(v[1]), float(v[2]))
			elif n is CharacterBody3D:
				(n as CharacterBody3D).velocity = Vector3(
						float(v[0]), float(v[1]), float(v[2]))
			else:
				printerr("capture : '%s' n'est pas un corps qu'on lance"
						% etape["lancer"])

		if etape.has("appeler"):
			var n := _trouver(_monde, str(etape["appeler"]))
			var m := str(etape.get("methode", ""))
			if n == null or not n.has_method(m):
				printerr("capture : %s.%s() introuvable" % [etape["appeler"], m])
			elif etape.has("argument"):
				n.call(m, etape["argument"])
			else:
				n.call(m)

		if etape.has("touche"):
			# Pressee ET relachee dans la meme image : is_action_just_pressed
			# reste vrai toute l'image, donc le jeu la voit malgre tout, et
			# rien ne reste enfonce apres.
			Input.action_press(str(etape["touche"]))
			Input.action_release(str(etape["touche"]))
		if etape.has("appui"):
			Input.action_press(str(etape["appui"]))
		if etape.has("relache"):
			Input.action_release(str(etape["relache"]))

		if etape.has("camera"):
			var c: Array = etape["camera"]
			_cam_pos = Vector3(float(c[0]), float(c[1]), float(c[2]))
			if etape.has("vise"):
				var v: Array = etape["vise"]
				_cam_cible = Vector3(float(v[0]), float(v[1]), float(v[2]))
			_placer_camera()


func _trouver(n: Node, nom: String) -> Node:
	if n == null:
		return null
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null


# On capture le SubViewport de rendu s'il existe : c'est la vraie image du
# jeu a sa resolution interne, sans l'agrandissement. Sinon, l'ecran entier.
func _image() -> Image:
	var sv := _trouver_subviewport(root)
	if sv != null:
		var t := sv.get_texture()
		if t != null:
			return t.get_image()
	var rt := root.get_texture()
	return rt.get_image() if rt != null else null


func _trouver_subviewport(n: Node) -> SubViewport:
	if n is SubViewport:
		return n
	for e in n.get_children():
		var trouve := _trouver_subviewport(e)
		if trouve != null:
			return trouve
	return null


# On cree notre propre camera plutot que de deplacer celle du jeu : la camera
# de poursuite reecrit sa position a chaque image de physique et annulerait
# tout placement. Une camera neuve et rendue active contourne le probleme quel
# que soit le script en place.
func _placer_camera() -> void:
	if _cam_pos == Vector3.INF:
		return
	var sv := _trouver_subviewport(root)
	if sv == null:
		return
	# Reutilisee si elle existe deja : un scenario peut replacer la camera en
	# cours de route, et en creer une seconde laisserait la premiere active
	# selon l'ordre d'appel. Le symptome serait une capture prise du mauvais
	# endroit, sans rien pour l'expliquer.
	var cam := sv.get_node_or_null("CameraCapture") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "CameraCapture"
		cam.fov = 60.0
		cam.near = 0.1
		cam.far = 900.0
		sv.add_child(cam)
	cam.global_position = _cam_pos
	if _cam_cible != Vector3.INF and _cam_pos.distance_squared_to(_cam_cible) > 0.001:
		cam.look_at(_cam_cible, Vector3.UP)
	cam.make_current()


func _options() -> Dictionary:
	var d := {}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--") and i + 1 < args.size():
			d[a.substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
	return d


func _vec(s: String) -> Vector3:
	var p := s.split(",")
	if p.size() != 3:
		return Vector3.INF
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
