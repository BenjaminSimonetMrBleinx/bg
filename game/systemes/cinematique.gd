# L'ouverture, au demarrage d'une nouvelle partie.
#
# CE QU'ELLE FAIT ET CE QU'ELLE NE FAIT PAS.
#
# Elle joue une liste de plans fixes pris DANS LE MONDE deja charge — pas une
# video, pas une scene a part. Trois raisons, et la troisieme est la vraie :
#
#   1. Une video pese, se reencode a chaque changement de decor, et jure avec
#      un rendu a 960x720 qu'elle ne partage pas.
#   2. Une scene separee obligerait a charger le monde deux fois.
#   3. Ce qu'on montre est le VRAI jeu. Une ouverture qui promet autre chose
#      que ce qui suit est un mensonge qu'on paie a la premiere image jouable.
#
# ELLE NE SE JOUE QU'UNE FOIS. « Nouvelle partie » efface la sauvegarde avant
# de charger le monde ; il suffit donc de regarder si quelque chose a ete
# repris. Rien a transmettre entre les deux scenes, rien a stocker.
extends Node

@export var reglages: Reglages
@export var sauvegarde: NodePath
@export var controleur: NodePath
@export var interface: NodePath

const FICHIER := "res://donnees/cinematique.json"

## Emis quand elle se termine, passee ou jouee jusqu'au bout.
signal finie

var _plans: Array = []
var _musique_chemin: String = ""
var _i: int = -1
var _reste: float = 0.0
var _joue: bool = false

var _camera: Camera3D
var _avant: Camera3D
var _voile: ColorRect
var _texte: Label
var _lecteur: AudioStreamPlayer
var _fondu: float = 1.0
var _sens: float = -1.0

## L'heure du monde avant l'ouverture, rendue a la fin. Voir _demarrer().
var _heure_avant: float = -1.0


func _ready() -> void:
	set_process(false)
	# On attend une image : la sauvegarde se reprend sur un appel differe, et
	# l'interroger tout de suite dirait toujours « rien de repris ».
	call_deferred("_decider")


func _decider() -> void:
	await get_tree().process_frame
	# ELLE NE DEMARRE PAS TOUTE SEULE SOUS UN OUTIL.
	#
	# Les suites de test chargent le monde et verifient l'etat qui suit.
	# L'ouverture y tournait : elle pose l'heure de ses plans — six heures du
	# matin pour le desert — et la suite `jour` l'a dit tout de suite, « la
	# mission impose 09.00 h, le monde est a 06.21 h ».
	#
	# On regarde --script et pas le mode headless : bg.ps1 lance les suites AVEC
	# une fenetre, sur l'ecran choisi, pour que Godot rende vraiment. Le premier
	# essai coupait sur headless et ne changeait donc rien.
	#
	# `jouer()` reste public : la situation de capture `cinematique` la force,
	# et c'est le seul endroit qui doit encore la voir.
	if "--script" in OS.get_cmdline_args():
		finie.emit()
		return
	var s := get_node_or_null(sauvegarde)
	if s != null and s.has_method("existe") and s.call("existe"):
		# Une partie en cours : on ne rejoue pas l'ouverture.
		finie.emit()
		return
	if not _charger():
		finie.emit()
		return
	_demarrer()


## La joue de force, quelle que soit la sauvegarde. POUR LES OUTILS.
##
## Une situation de capture reprend toujours une partie — c'est ce que fait
## monde.tscn au chargement — donc l'ouverture n'y demarre jamais et aucune
## image ne peut la montrer. Meme porte que Mission.aller_a(), pour la meme
## raison : ce qui se mesure et ce qui se joue ont besoin d'entrees separees.
##
## L'argument saute directement a un plan, pour capturer le troisieme sans
## attendre les douze secondes des deux premiers.
func jouer(depuis: int = 0) -> void:
	if _joue:
		return
	if not _charger():
		return
	_demarrer()
	if depuis > 0:
		_i = depuis - 1
		_suivant()


func _charger() -> bool:
	if not FileAccess.file_exists(FICHIER):
		push_warning("cinematique : %s introuvable" % FICHIER)
		return false
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(brut) != TYPE_DICTIONARY:
		push_error("cinematique : %s illisible" % FICHIER)
		return false
	_plans = (brut as Dictionary).get("plans", [])
	_musique_chemin = str((brut as Dictionary).get("musique", ""))
	return not _plans.is_empty()


func _demarrer() -> void:
	var vp := get_viewport()
	_avant = vp.get_camera_3d()

	# UNE CAMERA A ELLE, et pas celle du jeu.
	#
	# La camera de poursuite reecrit sa position a chaque image : lui poser un
	# plan revient a le perdre a l'image suivante. Le meme piege que pour les
	# captures, ou capture.gd cree aussi la sienne.
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.near = 0.1
	_camera.far = 900.0
	if _avant != null:
		_avant.get_parent().add_child(_camera)
	else:
		add_child(_camera)
	_camera.make_current()

	# L'HEURE EST EMPRUNTEE, PAS PRISE.
	#
	# Les plans posent leur propre heure pour avoir leur lumiere — l'aube sur
	# le desert, le plein jour sur la rue. Mais la mission impose la sienne au
	# demarrage (neuf heures, dans mission1.json), et l'ouverture l'ecrasait :
	# la suite `jour` l'a dit tout de suite, « la mission impose 09.00 h, le
	# monde est a 06.21 h ».
	#
	# On la note ici et on la rend a la fin. Sauter l'ouverture ou la regarder
	# en entier laisse donc le monde exactement dans le meme etat — et c'est la
	# seule facon qu'une cinematique sautable ne change rien au jeu.
	_heure_avant = Reglages.heure
	_poser_le_voile()
	_bloquer_le_jeu(true)

	if _musique_chemin != "" and ResourceLoader.exists(_musique_chemin):
		_lecteur = AudioStreamPlayer.new()
		_lecteur.stream = load(_musique_chemin)
		_lecteur.bus = "Musique"
		add_child(_lecteur)
		_lecteur.play()

	_joue = true
	_i = -1
	_suivant()
	set_process(true)


# Le voile et le carton vivent dans l'interface du jeu, donc DANS le viewport :
# ils partagent le grain du rendu. Un texte net sur une image de 960 pixels se
# verrait comme une incrustation.
func _poser_le_voile() -> void:
	var hote := get_node_or_null(interface) as Control
	if hote == null:
		return
	_voile = ColorRect.new()
	_voile.color = Color(0.02, 0.02, 0.03, 1.0)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	hote.add_child(_voile)

	_texte = Label.new()
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texte.add_theme_font_size_override("font_size", 17)
	_texte.add_theme_color_override("font_color", Color(0.949, 0.925, 0.867))
	_texte.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	_texte.add_theme_constant_override("outline_size", 6)
	_texte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texte.offset_top = 250.0
	hote.add_child(_texte)


## Ce qu'on garde a l'ecran pendant l'ouverture : le voile et le carton, et
## rien d'autre. Le reste est masque puis remis tel qu'on l'a trouve.
var _masques: Array[CanvasItem] = []


func _bloquer_le_jeu(bloque: bool) -> void:
	var c := get_node_or_null(controleur)
	if c != null and c.has_method("set_process_unhandled_input"):
		c.set_process_unhandled_input(not bloque)
	if c != null:
		c.set_process(not bloque)
	# La souris reste visible : on ne la capture pas pour regarder un film.
	Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE if bloque
			else Input.MOUSE_MODE_CAPTURED)

	# LE HUD N'A RIEN A FAIRE SUR UNE OUVERTURE.
	#
	# Vu a la premiere capture : l'argent, la famille, la reputation, la
	# minimap et l'objectif de mission s'affichaient par-dessus les cartons.
	# Trois ressources et un plan de ville pendant qu'on presente le
	# personnage, c'est le contraire de ce qu'une ouverture fait — elle
	# demande qu'on regarde une chose a la fois.
	#
	# On note ce qu'on masque plutot que de tout rallumer a la fin : un element
	# deja cache pour une autre raison — le cadre de dialogue, le menu pause —
	# ne doit pas reapparaitre parce que l'ouverture s'est terminee.
	var hote := get_node_or_null(interface) as Control
	if hote == null:
		return
	if bloque:
		_masques.clear()
		for e in hote.get_children():
			if e is CanvasItem and e != _voile and e != _texte \
					and (e as CanvasItem).visible:
				_masques.append(e as CanvasItem)
				(e as CanvasItem).visible = false
	else:
		for e in _masques:
			if is_instance_valid(e):
				e.visible = true
		_masques.clear()


func _suivant() -> void:
	_i += 1
	if _i >= _plans.size():
		_terminer()
		return
	var p: Dictionary = _plans[_i]
	var c: Array = p.get("camera", [0, 2, 0])
	var v: Array = p.get("vise", [0, 0, 0])
	_camera.global_position = Vector3(float(c[0]), float(c[1]), float(c[2]))
	_camera.look_at(Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3.UP)

	if p.has("heure"):
		var t := get_tree().get_first_node_in_group(Temps.GROUPE) as Temps
		if t != null:
			t.regler(float(p["heure"]))

	if _texte != null:
		_texte.text = str(p.get("carton", ""))

	# Le fondu : « ouvre » part du noir, « ferme » y retourne, et sans mention
	# on reste ou l'on est. Un fondu a chaque plan hacherait l'ouverture.
	var f := str(p.get("fondu", ""))
	if f == "ouvre":
		_fondu = 1.0
		_sens = -1.0
	elif f == "ferme":
		_sens = 1.0
	else:
		_sens = -1.0
	_reste = float(p.get("duree", 3.0))


func _process(delta: float) -> void:
	if not _joue:
		return
	# ELLE SE PASSE A LA PREMIERE TOUCHE. Une ouverture qu'on ne peut pas
	# sauter se deteste au deuxieme lancement, et on relance beaucoup un jeu
	# qu'on developpe.
	if Input.is_anything_pressed():
		_terminer()
		return

	_fondu = clampf(_fondu + _sens * delta * 1.6, 0.0, 1.0)
	if _voile != null:
		_voile.color.a = _fondu
	if _texte != null:
		_texte.modulate.a = 1.0 - _fondu

	_reste -= delta
	if _reste <= 0.0:
		_suivant()


func _terminer() -> void:
	if not _joue:
		return
	_joue = false
	set_process(false)
	if _lecteur != null:
		# On coupe court plutot que de laisser le theme finir sur le jeu : la
		# musique d'ouverture appartient a l'ouverture.
		var f := create_tween()
		f.tween_property(_lecteur, "volume_db", -40.0, 1.2)
		f.tween_callback(_lecteur.queue_free)
	if _voile != null:
		var t := create_tween()
		t.tween_property(_voile, "color:a", 0.0, 0.8)
		t.tween_callback(_voile.queue_free)
	if _texte != null:
		_texte.queue_free()
	if _avant != null and is_instance_valid(_avant):
		_avant.make_current()
	if _camera != null:
		_camera.queue_free()
	# On rend l'heure empruntee. Sans ca, sauter l'ouverture laisse le monde a
	# l'aube du premier plan alors que la mission demarre a neuf heures.
	if _heure_avant >= 0.0:
		var t := get_tree().get_first_node_in_group(Temps.GROUPE) as Temps
		if t != null:
			t.regler(_heure_avant)
	_bloquer_le_jeu(false)
	finie.emit()
