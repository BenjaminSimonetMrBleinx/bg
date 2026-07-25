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
extends SceneTree

var _sortie := ""
var _frames_a_attendre := 12
var _n := 0
var _cam_pos := Vector3.INF
var _cam_cible := Vector3.INF


func _initialize() -> void:
	var args := _options()
	_sortie = args.get("sortie", "capture.png")
	_frames_a_attendre = int(args.get("frames", "12"))
	if args.has("cam"):
		_cam_pos = _vec(args["cam"])
	if args.has("vise"):
		_cam_cible = _vec(args["vise"])

	var chemin: String = args.get("scene", ProjectSettings.get_setting("application/run/main_scene", ""))
	if chemin == "" or not ResourceLoader.exists(chemin):
		printerr("capture : scene introuvable (%s)" % chemin)
		quit(1)
		return

	var ps := ResourceLoader.load(chemin) as PackedScene
	if ps == null:
		printerr("capture : chargement impossible (%s)" % chemin)
		quit(1)
		return
	root.add_child(ps.instantiate())


func _process(_delta: float) -> bool:
	_n += 1
	if _n == 2:
		_placer_camera()
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
	var cam := Camera3D.new()
	cam.name = "CameraCapture"
	cam.fov = 60.0
	cam.near = 0.1
	cam.far = 500.0
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
