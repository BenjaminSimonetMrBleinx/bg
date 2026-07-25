# La roue des outils.
#
# Se maintient ouverte tant que la touche est enfoncee, se ferme en
# equipant ce qui est selectionne. C'est le geste des jeux de l'epoque : on
# ne navigue pas dans un menu, on fait un mouvement.
#
# Elle est DESSINEE, pas assemblee en noeuds : le nombre de parts vient de
# donnees/outils.json, et une roue faite de noeuds poses a la main devrait
# etre refaite a chaque objet ajoute. Ici, ajouter une entree au fichier
# ajoute une part, sans toucher a quoi que ce soit.
class_name Roue
extends Control

signal choisi(index: int)

@export var reglages: Reglages
@export var equipement: NodePath

var _eq: Equipement
var _ouverte: bool = false
var _selection: int = 0
var _ouverture: float = 0.0        # 0 fermee, 1 ouverte — pour l'animation


func _ready() -> void:
	_eq = get_node_or_null(equipement) as Equipement
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func ouverte() -> bool:
	return _ouverte


## Ouvre la roue. Le temps ne s'arrete pas completement : un ralenti garde le
## monde vivant derriere, et c'est ce que faisaient les jeux de l'epoque.
func ouvrir() -> void:
	if _eq == null or _eq.nombre() == 0:
		return
	_ouverte = true
	visible = true
	# On repart de l'objet en main, ou de la premiere part si les mains sont
	# vides : la selection doit toujours commencer quelque part de sense.
	_selection = _eq.actif() if _eq.actif() >= 0 else 0
	Engine.time_scale = reglages.roue_ralenti


func fermer(valider: bool) -> void:
	if not _ouverte:
		return
	_ouverte = false
	Engine.time_scale = 1.0
	if valider:
		_eq.equiper(_selection)
		choisi.emit(_selection)


func _process(delta: float) -> void:
	# L'ouverture s'anime meme quand le jeu est ralenti : sinon la roue met
	# une demi-seconde reelle a apparaitre et le geste devient mou.
	var vers := 1.0 if _ouverte else 0.0
	var pas := delta / maxf(0.01, reglages.roue_ouverture) / maxf(0.01, Engine.time_scale)
	_ouverture = move_toward(_ouverture, vers, pas)
	if not _ouverte and _ouverture <= 0.0:
		visible = false
	queue_redraw()


func _unhandled_input(evenement: InputEvent) -> void:
	if not _ouverte or _eq == null:
		return
	var n := _eq.nombre()
	if evenement.is_action_pressed("droite"):
		_selection = (_selection + 1) % n
	elif evenement.is_action_pressed("gauche"):
		_selection = (_selection - 1 + n) % n


func _draw() -> void:
	if _eq == null or _ouverture <= 0.0:
		return
	var n := _eq.nombre()
	if n == 0:
		return

	var centre := size / 2.0
	var rayon: float = reglages.roue_rayon * _ouverture
	var police := get_theme_default_font()
	var taille := 14

	# Voile sombre : sans lui, un texte clair sur une rue nocturne deja
	# sombre et bruitee devient illisible.
	draw_rect(Rect2(Vector2.ZERO, size),
			Color(0.02, 0.03, 0.05, 0.45 * _ouverture))

	for i in n:
		# Premiere part en haut, puis dans le sens horaire. Un depart a
		# droite obligerait a compter mentalement.
		var angle := -PI / 2.0 + TAU * float(i) / float(n)
		var p := centre + Vector2(cos(angle), sin(angle)) * rayon
		var vise := i == _selection

		var fond := (Color(0.85, 0.70, 0.35, 0.92) if vise
				else Color(0.10, 0.11, 0.15, 0.80))
		draw_circle(p, (20.0 if vise else 16.0) * _ouverture, fond)
		draw_arc(p, (20.0 if vise else 16.0) * _ouverture, 0.0, TAU, 20,
				Color(0.60, 0.56, 0.46, 0.9), 1.0)

		# Un point plein signale ce qui est deja equipe, meme si la selection
		# est ailleurs : sans ce reperage on ne sait plus ce qu'on tient.
		if i == _eq.actif():
			draw_circle(p, 4.0 * _ouverture, Color(0.95, 0.93, 0.88, 0.95))

		if police != null and _ouverture > 0.6:
			var texte := _eq.nom_de(i)
			var l := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
					-1, taille).x
			var couleur := (Color(0.98, 0.96, 0.90) if vise
					else Color(0.72, 0.70, 0.66))
			draw_string(police, p + Vector2(-l / 2.0, 34.0),
					texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
