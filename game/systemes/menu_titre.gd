# Le dessin de l'ecran-titre, et rien d'autre.
#
# Il vit DANS le SubViewport du titre, a la resolution du jeu : c'est ce qui
# fait que le menu a le meme grain que ce qu'il annonce.
#
# IL NE CONNAIT PAS Titre, et c'est delibere : deux scripts qui se nomment l'un
# l'autre par class_name forment un cycle que GDScript refuse de compiler. Le
# titre POUSSE ici ce qu'il faut peindre ; la seule chose qui remonte, c'est ou
# chaque entree a ete posee, parce que lui seul le sait.
class_name MenuTitre
extends Control

## Le titre, dans l'olive de la case du tableau periodique et l'ambre du desert
## - les couleurs de l'interface du jeu.
const OLIVE := Color(0.52, 0.55, 0.18)
const AMBRE := Color(0.78, 0.6, 0.25)
const ROUGE := Color(0.85, 0.35, 0.22)
const CHOISI := Color(0.95, 0.78, 0.42)
const REPOS := Color(0.55, 0.53, 0.46)
const FOND := Color(0.06, 0.06, 0.05)

var _liste: Array = []
var _choix: int = 0
var _confirme: bool = false

## Ou chaque entree a ete posee, dans le repere du rendu interne. Rempli au
## dessin : c'est le dessin qui decide de la mise en page, donc c'est lui qui
## sait ce qu'on peut cliquer.
var _zones: Array[Rect2] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Le curseur n'entre pas dans ce viewport : c'est Titre qui convertit sa
	# position et interroge index_sous(). Laisser le filtre par defaut ferait
	# croire a une zone cliquable qui ne recevra jamais rien.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ce qu'il y a a peindre. Appele par Titre a chaque changement d'etat.
func montrer(liste: Array, choix: int, confirme: bool) -> void:
	_liste = liste
	_choix = choix
	_confirme = confirme
	queue_redraw()


## L'entree posee sous ce point, ou -1. Le point est attendu dans le repere du
## RENDU INTERNE, pas dans celui de la fenetre : la conversion appartient a
## Titre, qui est le seul a savoir de combien l'image est agrandie.
func index_sous(p: Vector2) -> int:
	for i in _zones.size():
		if _zones[i].has_point(p):
			return i
	return -1


func _draw() -> void:
	var police := get_theme_default_font()
	if police == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), FOND)
	var cx := size.x / 2.0

	_texte(police, "BREAKING BAD", Vector2(cx, size.y * 0.24), 34, OLIVE)
	_texte(police, "GAME", Vector2(cx, size.y * 0.24 + 32.0), 20, AMBRE)

	var depart := size.y * 0.56
	if _confirme:
		_texte(police, "Ecraser la sauvegarde ?", Vector2(cx, depart - 36.0),
				15, ROUGE)

	_zones = []
	for i in _liste.size():
		var y := depart + float(i) * 28.0
		var sel := i == _choix
		var couleur := CHOISI if sel else REPOS
		var etiquette: String = ("- " + str(_liste[i]) + " -") if sel else str(_liste[i])
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
