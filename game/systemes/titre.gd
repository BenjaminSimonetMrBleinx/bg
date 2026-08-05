# L'ecran-titre et son menu.
#
# C'est la premiere chose qu'on voit : le nom du jeu, et de quoi commencer.
# Il PRECEDE le monde - main_scene pointe ici - et charge monde.tscn a l'action.
#
# Trois entrees, et la premiere n'apparait que s'il y a de quoi reprendre :
#   Reprendre       recharge le dernier point. Le monde s'en charge tout seul au
#                   demarrage (le auto-load de la sauvegarde) ; ici on ne fait
#                   que le lancer.
#   Nouvelle partie repart de zero. Si une sauvegarde existe, on CONFIRME avant
#                   de l'effacer : une partie ne se perd pas sur un clic.
#   Quitter         ferme le jeu.
#
# Le menu se dessine a la main et se navigue au clavier (gaz/frein, interagir)
# comme le menu pause et l'ecran de fin, pour que les trois se ressemblent. Il
# se clique aussi : ici le curseur est visible, une liste qui l'ignore se lit
# comme une interface cassee.
class_name Titre
extends Control

const MONDE := "res://scenes/monde.tscn"

## Deux vues : la liste racine, et la confirmation d'ecrasement.
enum Vue { RACINE, CONFIRME }

var _vue: int = Vue.RACINE
var _choix: int = 0
var _racine: Array[String] = []
var _zones: Array[Rect2] = []
var _clic_avant: bool = false


func _ready() -> void:
	# Raccourci de developpement : lancer avec -Ou saute le titre et va droit au
	# monde, a l'endroit demande (voir bg.ps1 jouer -Ou). On ne clique pas un
	# menu vingt fois par soiree pour aller regarder le desert.
	if "--ou" in OS.get_cmdline_user_args():
		_lancer_monde()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# On sort d'un jeu qui capture la souris ; sur le titre, on la veut visible.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_reconstruire()
	set_process(true)
	queue_redraw()


## La liste racine, refaite selon ce qui existe : « Reprendre » n'a de sens que
## s'il y a une sauvegarde a reprendre.
func _reconstruire() -> void:
	_racine = []
	if sauvegarde_existe():
		_racine.append("Reprendre")
	_racine.append("Nouvelle partie")
	_racine.append("Quitter")
	_choix = 0


## Y a-t-il une partie a reprendre ? On relit le fichier de sauvegarde, dont le
## chemin appartient a Sauvegarde : le titre n'invente pas le sien.
func sauvegarde_existe() -> bool:
	return FileAccess.file_exists(Sauvegarde.FICHIER)


## Les entrees actuellement affichees. Public : les tests le lisent.
func options() -> Array:
	return ["Non", "Oui"] if _vue == Vue.CONFIRME else _racine


func _process(_delta: float) -> void:
	var n := options().size()
	var bouge := 0
	if Input.is_action_just_pressed("frein"):
		bouge = 1
	elif Input.is_action_just_pressed("gaz"):
		bouge = -1
	if bouge != 0:
		_choix = (_choix + bouge + n) % n
		queue_redraw()
	_suivre_la_souris()
	if Input.is_action_just_pressed("interagir"):
		valider()


## Agit sur l'entree selectionnee. Public : les tests l'appellent.
func valider() -> void:
	if _vue == Vue.CONFIRME:
		# options() = ["Non", "Oui"]. Oui efface et lance ; Non revient.
		if _choix == 1:
			effacer_sauvegarde()
			_lancer_monde()
		else:
			_vue = Vue.RACINE
			_reconstruire()
			queue_redraw()
		return

	match _racine[_choix]:
		"Reprendre":
			_lancer_monde()
		"Nouvelle partie":
			# Une sauvegarde existe : on ne l'ecrase pas sans demander.
			if sauvegarde_existe():
				_vue = Vue.CONFIRME
				_choix = 0
				queue_redraw()
			else:
				_lancer_monde()
		"Quitter":
			get_tree().quit()


## Efface la sauvegarde. Public : sert au « Nouvelle partie » confirme, et aux
## tests.
func effacer_sauvegarde() -> void:
	if sauvegarde_existe():
		DirAccess.remove_absolute(Sauvegarde.FICHIER)


func _lancer_monde() -> void:
	get_tree().change_scene_to_file(MONDE)


# --------------------------------------------------------------------- souris


func _suivre_la_souris() -> void:
	var m := get_global_mouse_position()
	for i in _zones.size():
		if _zones[i].has_point(m) and _choix != i:
			_choix = i
			queue_redraw()
			break
	var clic := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if clic and not _clic_avant:
		for i in _zones.size():
			if _zones[i].has_point(m):
				_choix = i
				valider()
				break
	_clic_avant = clic


# ---------------------------------------------------------------------- dessin


func _draw() -> void:
	var police := get_theme_default_font()
	if police == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.06, 0.05))
	var cx := size.x / 2.0

	# Le titre, dans l'olive de la case du tableau periodique et l'ambre du
	# desert - les couleurs de l'interface du jeu.
	_texte(police, "BREAKING BAD", Vector2(cx, size.y * 0.24), 34,
			Color(0.52, 0.55, 0.18))
	_texte(police, "GAME", Vector2(cx, size.y * 0.24 + 32.0), 20,
			Color(0.78, 0.6, 0.25))

	var liste := options()
	var depart := size.y * 0.56
	if _vue == Vue.CONFIRME:
		_texte(police, "Ecraser la sauvegarde ?", Vector2(cx, depart - 36.0),
				15, Color(0.85, 0.35, 0.22))

	_zones = []
	for i in liste.size():
		var y := depart + float(i) * 28.0
		var sel := i == _choix
		var couleur := Color(0.95, 0.78, 0.42) if sel else Color(0.55, 0.53, 0.46)
		var etiquette: String = ("- " + str(liste[i]) + " -") if sel else str(liste[i])
		_texte(police, etiquette, Vector2(cx, y), 16, couleur)
		_zones.append(Rect2(cx - 110.0, y - 3.0, 220.0, 26.0))


func _texte(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color) -> void:
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille).x
	var p := ou - Vector2(largeur / 2.0, 0.0)
	police.draw_string(get_canvas_item(), p + Vector2(1, 1), texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0, 0, 0, couleur.a))
	police.draw_string(get_canvas_item(), p, texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille, couleur)
