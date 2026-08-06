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
#
# IL PASSE PAR LE MEME PIPELINE QUE LE JEU. Le menu est dessine dans un
# SubViewport a la resolution de reglages.tres, puis agrandi - exactement comme
# le monde et comme tout le reste de l'interface, qui vit deja dans le viewport
# du jeu. Dessine en pleine resolution, l'ecran-titre etait plus NET que le jeu
# qu'il annonce : le premier ecran promettait une finesse que la premiere image
# de jeu dementait.
#
# Ce noeud tient l'etat et les actions ; menu_titre.gd tient le dessin.
class_name Titre
extends Node

const MONDE := "res://scenes/monde.tscn"

## Deux vues : la liste racine, et la confirmation d'ecrasement.
enum Vue { RACINE, CONFIRME }

@export var reglages: Reglages

var _vue: int = Vue.RACINE
var _choix: int = 0
var _racine: Array[String] = []
var _clic_avant: bool = false

@onready var _rendu: SubViewport = $Rendu
@onready var _menu: MenuTitre = $Rendu/Menu
@onready var _ecran: TextureRect = $Affichage/Ecran


func _ready() -> void:
	# Raccourci de developpement : lancer avec -Ou saute le titre et va droit au
	# monde, a l'endroit demande (voir bg.ps1 jouer -Ou). On ne clique pas un
	# menu vingt fois par soiree pour aller regarder le desert.
	if "--ou" in OS.get_cmdline_user_args():
		_lancer_monde()
		return
	_configurer_ecran()
	# On sort d'un jeu qui capture la souris ; sur le titre, on la veut visible.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_reconstruire()
	set_process(true)


# La resolution et le filtrage viennent de reglages.tres, comme pour le monde :
# bouger le curseur du rendu interne doit deplacer le titre avec le jeu, sinon
# les deux divergent au premier reglage et personne ne s'en apercoit avant une
# capture.
func _configurer_ecran() -> void:
	if reglages == null:
		push_error("titre : aucune ressource Reglages assignee")
		return
	_rendu.size = Vector2i(reglages.largeur_rendu, reglages.hauteur_rendu)
	_rendu.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ecran.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR if reglages.filtrage_lineaire
		else CanvasItem.TEXTURE_FILTER_NEAREST
	)
	_ecran.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ecran.stretch_mode = TextureRect.STRETCH_SCALE


## La liste racine, refaite selon ce qui existe : « Reprendre » n'a de sens que
## s'il y a une sauvegarde a reprendre.
func _reconstruire() -> void:
	_racine = []
	if sauvegarde_existe():
		_racine.append("Reprendre")
	_racine.append("Nouvelle partie")
	_racine.append("Quitter")
	_choix = 0
	_rafraichir()


## Y a-t-il une partie a reprendre ? On relit le fichier de sauvegarde, dont le
## chemin appartient a Sauvegarde : le titre n'invente pas le sien.
func sauvegarde_existe() -> bool:
	return FileAccess.file_exists(Sauvegarde.FICHIER)


## Les entrees actuellement affichees. Public : les tests le lisent.
func options() -> Array:
	return ["Non", "Oui"] if _vue == Vue.CONFIRME else _racine


# Le menu ne va pas chercher l'etat, on le lui donne. Les tests appellent
# _reconstruire() et valider() sans passer par _ready : le menu peut donc ne pas
# exister encore quand l'etat change.
func _rafraichir() -> void:
	if _menu != null:
		_menu.montrer(options(), _choix, _vue == Vue.CONFIRME)


func _process(_delta: float) -> void:
	var n := options().size()
	var bouge := 0
	if Input.is_action_just_pressed("frein"):
		bouge = 1
	elif Input.is_action_just_pressed("gaz"):
		bouge = -1
	if bouge != 0:
		_choix = (_choix + bouge + n) % n
		_rafraichir()
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
		return

	match _racine[_choix]:
		"Reprendre":
			_lancer_monde()
		"Nouvelle partie":
			# Une sauvegarde existe : on ne l'ecrase pas sans demander.
			if sauvegarde_existe():
				_vue = Vue.CONFIRME
				_choix = 0
				_rafraichir()
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


# LA SOURIS N'ENTRE PAS TOUTE SEULE DANS UN SUBVIEWPORT (piege 9) : le menu
# dessine a 512x384 pendant que le curseur, lui, se promene dans une fenetre de
# 1920 de large. Sans conversion, on survole une entree trois fois plus bas que
# celle qu'on voit.
#
# L'ecran est un simple agrandissement plein cadre - pas de bandes noires, pas
# de recadrage - donc la conversion est un rapport d'echelle et rien d'autre.
func _souris_dans_le_rendu() -> Vector2:
	var fenetre := get_window()
	if fenetre == null:
		return Vector2(-1.0, -1.0)
	var cadre := Vector2(fenetre.size)
	if cadre.x <= 0.0 or cadre.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var rendu := Vector2(_rendu.size)
	return fenetre.get_mouse_position() * (rendu / cadre)


func _suivre_la_souris() -> void:
	var m := _souris_dans_le_rendu()
	var sous := _menu.index_sous(m)
	if sous >= 0 and _choix != sous:
		_choix = sous
		_menu.queue_redraw()
	var clic := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if clic and not _clic_avant and sous >= 0:
		_choix = sous
		valider()
	_clic_avant = clic
