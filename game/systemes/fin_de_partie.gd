# L'ecran de Game Over.
#
# Quatre choses se declenchent ensemble, et l'ordre compte plus que chacune :
#
#   1. le temps RALENTIT — pas net, sur une seconde, sinon on ne voit pas la
#      chute qu'on vient de provoquer
#   2. l'image se DECOLORE, progressivement, par le meme mouvement
#   3. le corps s'effondre en ragdoll (declenche par le joueur, pas ici)
#   4. la boucle sonore demarre et s'efface sur dix secondes
#
# Puis le texte, puis l'invite a recommencer. Elle n'apparait qu'au bout de
# cinq secondes : proposee tout de suite, on la presse par reflexe et on ne
# voit rien de ce qui precede.
#
# LE RALENTI SE FAIT PAR time_scale, ce qui ralentit AUSSI cet ecran. Tout ce
# qui est compte ici l'est donc en temps reel, en cumulant des deltas non
# ajustes — un Timer ou un tween ordinaire durerait quatre fois trop longtemps
# et le joueur attendrait vingt secondes une invite annoncee a cinq.
class_name FinDePartie
extends Control

signal recommence

## Delai avant que l'invite apparaisse, et delai au bout duquel on repart tout
## seul si personne ne touche a rien. Les deux en SECONDES REELLES.
const AVANT_INVITE := 5.0
const AVANT_AUTOMATIQUE := 15.0

## Duree du fondu de la boucle sonore. Tres lent, volontairement : c'est le
## seul element qui continue de vivre sur un ecran fige.
const FONDU_SON := 10.0

const RALENTI := 0.25
const ENTREE := 1.0

@export var reglages: Reglages

var _actif: bool = false
var _titre: String = ""
var _temps: float = 0.0
var _lecteur: AudioStreamPlayer
var _decoloration: float = 0.0
var _ecran: CanvasItem


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On continue de tourner quand tout le reste est suspendu : c'est le seul
	# noeud qui doit rester vivant sur un ecran de fin.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lecteur = AudioStreamPlayer.new()
	_lecteur.name = "Boucle"
	_lecteur.bus = "Musique"
	_lecteur.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_lecteur)
	set_process(true)


## Le TextureRect qui affiche le rendu du jeu. C'est LUI qu'on decolore, et pas
## la scene : passer chaque materiau en niveaux de gris demanderait de les
## parcourir tous et de savoir les remettre. Ici on agit sur l'image finale,
## une fois, et le retour en arriere est gratuit.
func brancher_l_ecran(ecran: CanvasItem) -> void:
	_ecran = ecran


func actif() -> bool:
	return _actif


## `titre` est ce qui s'affiche en grand : « Vous etes mort », « Jesse est
## mort »... Le texte fait partie de la scene qu'on vient de jouer, donc c'est
## l'appelant qui le donne.
func declencher(titre: String) -> void:
	if _actif:
		return
	_actif = true
	_titre = titre
	_temps = 0.0
	_decoloration = 0.0
	visible = true
	Engine.time_scale = RALENTI

	var flux := load("res://assets/sons/mission/game_over.wav")
	if flux != null:
		if flux is AudioStreamWAV:
			(flux as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_lecteur.stream = flux
		_lecteur.volume_db = 0.0
		_lecteur.play()


func _process(_delta: float) -> void:
	if not _actif:
		return
	# LE TEMPS REEL, et pas celui du jeu. Engine.time_scale vaut 0,25 : un
	# delta ordinaire ferait durer cinq secondes annoncees vingt secondes
	# vecues, et le joueur croirait le jeu bloque.
	var reel := get_process_delta_time() / maxf(0.01, Engine.time_scale)
	_temps += reel

	_decoloration = clampf(_temps / ENTREE, 0.0, 1.0)
	if _ecran != null:
		# Vers le gris, par la couleur de modulation. C'est un fondu vers le
		# blanc-gris qui desature a l'oeil sans toucher au rendu 3D.
		var g := 1.0 - 0.55 * _decoloration
		_ecran.modulate = Color(g, g, g, 1.0)

	if _lecteur.playing:
		# -40 dB est inaudible ; on n'arrete pas le lecteur pour autant, la
		# boucle doit pouvoir repartir si le joueur reste la.
		_lecteur.volume_db = lerpf(0.0, -40.0,
				clampf(_temps / FONDU_SON, 0.0, 1.0))

	if _temps >= AVANT_INVITE and Input.is_action_just_pressed("interagir"):
		_repartir()
	elif _temps >= AVANT_AUTOMATIQUE:
		_repartir()

	queue_redraw()


func _repartir() -> void:
	_actif = false
	visible = false
	Engine.time_scale = 1.0
	_lecteur.stop()
	if _ecran != null:
		_ecran.modulate = Color.WHITE
	recommence.emit()


func _draw() -> void:
	if not _actif:
		return
	var police := get_theme_default_font()
	if police == null:
		return

	# Un voile qui s'installe, pas un rideau. Il monte avec la decoloration :
	# les deux racontent la meme chose et doivent avancer ensemble.
	draw_rect(Rect2(Vector2.ZERO, size),
			Color(0.02, 0.02, 0.03, 0.55 * _decoloration))

	if _temps < 0.35:
		return

	var apparition := clampf((_temps - 0.35) / 0.8, 0.0, 1.0)
	_ecrire(police, "GAME OVER", Vector2(size.x / 2.0, size.y * 0.40), 30,
			Color(0.78, 0.13, 0.11, apparition))
	_ecrire(police, _titre, Vector2(size.x / 2.0, size.y * 0.40 + 26.0), 15,
			Color(0.93, 0.90, 0.85, apparition))

	if _temps >= AVANT_INVITE:
		# Le clignotement lent est ce qui distingue une invite d'un titre. Il
		# bat en temps reel, comme tout le reste de cet ecran.
		var battement := 0.55 + 0.45 * sin(_temps * 3.0)
		_ecrire(police, "F   Recommencer",
				Vector2(size.x / 2.0, size.y * 0.72), 14,
				Color(0.949, 0.776, 0.42, battement))


func _ecrire(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color) -> void:
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille).x
	var p := ou - Vector2(largeur / 2.0, 0.0)
	var ombre := Color(0.0, 0.0, 0.0, couleur.a)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		police.draw_string(get_canvas_item(), p + d, texte,
				HORIZONTAL_ALIGNMENT_LEFT, -1, taille, ombre)
	police.draw_string(get_canvas_item(), p, texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
