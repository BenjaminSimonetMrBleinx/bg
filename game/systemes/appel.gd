# UN APPEL QUI TOMBE PENDANT QU'ON CONDUIT.
#
# Le telephone sonne a une etape de mission donnee, et seulement AU VOLANT. On
# decroche, on raccroche, ou on laisse sonner — les trois sont des reponses, et
# aucune n'est gratuite.
#
# CE QUE CE SYSTEME REMPLACE. Toute cette mecanique vivait dans « Un simple
# service », une mission de test ecrite pour l'eprouver avant que les vraies
# missions existent. Elles existent : le banc a ete retire et le mecanisme sort
# ici, configurable par la scene. Les missions 2 a 5 le brancheront sans
# reecrire une ligne.
#
# POURQUOI AU VOLANT, ET PAS DES LE DEBUT DE L'ETAPE. Un appel qui tombe
# pendant qu'on cherche encore ses cles se prend pour un bug. La scene veut
# Walter deja parti, une main sur le telephone : c'est la que la demande banale
# devient couteuse, parce qu'il faut faire demi-tour pour l'honorer.
class_name Appel
extends Control

## L'etape de mission pendant laquelle cet appel peut tomber.
@export var etape: String = ""

## La conversation jouee si l'on decroche. Sa cle dans donnees/dialogues.json.
@export var conversation: String = ""

## Apres combien de secondes AU VOLANT le telephone sonne.
##
## Le compte repart a zero des qu'on descend : ce sont des secondes de CONDUITE,
## pas des secondes depuis le debut de l'etape. La premiere version comptait
## depuis le depart, donc l'appel tombait a l'instant ou l'on s'asseyait.
@export_range(0.0, 120.0, 1.0) var apres_secondes: float = 20.0

## Combien de temps il sonne avant de renoncer. Assez long pour decider en
## conduisant, assez court pour que ne rien faire soit une reponse.
@export_range(1.0, 30.0, 0.5) var duree_sonnerie: float = 9.0

## Ce que coute de ne pas repondre, en points de famille. On n'a rien promis,
## mais on a ignore sa femme.
@export_range(0, 30, 1) var cout_ignore: int = 5

@export var joueur: NodePath
@export var controleur: NodePath
@export var dialogue: NodePath

## LA SONNERIE EST A NOUS, pas au systeme audio.
##
## Audio.bruit() fabrique un lecteur jetable et l'oublie : personne ne peut plus
## l'arreter. Le telephone continuait donc de sonner apres qu'on avait decroche,
## ce qui est exactement le contraire de ce que decrocher veut dire.
const SON_SONNERIE := "res://assets/sons/telephone/phone_ring.wav"

var _joueur: Node3D
var _controleur: Node
var _dialogue: Dialogue
var _lecteur: AudioStreamPlayer

var _sonne: float = 0.0
var _volant_depuis: float = 0.0
var _fait: bool = false
var _en_appel: bool = false
var _decroche: bool = false


func _ready() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joueur = get_node_or_null(joueur) as Node3D
	_controleur = get_node_or_null(controleur)
	_dialogue = get_node_or_null(dialogue) as Dialogue
	_lecteur = AudioStreamPlayer.new()
	_lecteur.bus = Audio.BUS_INTERFACE
	_lecteur.stream = ResourceLoader.load(SON_SONNERIE) as AudioStream
	add_child(_lecteur)
	set_process(true)


## A-t-on decroche ? Lu par le scenario pour savoir si une promesse a ete faite.
func decroche() -> bool:
	return _decroche


## L'appel a-t-il deja eu lieu ? Il ne tombe qu'une fois par partie.
func fait() -> bool:
	return _fait


## Tout remettre a zero. Recommencer une partie doit redonner un telephone qui
## n'a pas encore sonne.
func reinitialiser() -> void:
	_sonne = 0.0
	_volant_depuis = 0.0
	_fait = false
	_en_appel = false
	_decroche = false
	if _lecteur != null:
		_lecteur.stop()


func _process(delta: float) -> void:
	if _joueur == null or etape == "":
		return

	# LE COMPTE REPART A ZERO DES QU'ON DESCEND.
	_volant_depuis = (_volant_depuis + delta) if _au_volant() else 0.0

	if _sonne > 0.0:
		_pendant_la_sonnerie(delta)
		return

	if _fait or not _a_la_bonne_etape():
		return
	if _volant_depuis > apres_secondes:
		_fait = true
		_sonne = duree_sonnerie
		_lecteur.play()
		queue_redraw()


# DECROCHER EST UNE TOUCHE, RACCROCHER EN EST UNE AUTRE, ET NE RIEN FAIRE EN
# EST UNE TROISIEME.
#
# Laisser sonner marchait deja, mais obligeait a attendre neuf secondes pour
# refuser : le silence etait une reponse qu'on ne pouvait pas DONNER, seulement
# subir. T raccroche tout de suite, et coute la meme chose — ce qu'on paie,
# c'est de ne pas avoir parle, pas d'avoir attendu.
func _pendant_la_sonnerie(delta: float) -> void:
	_sonne = maxf(0.0, _sonne - delta)

	if Input.is_action_just_pressed("interagir"):
		_repondre()
		return
	if Input.is_action_just_pressed("telephone"):
		_raccrocher()
		return

	# Un telephone qui sonne dans le vide finit toujours par se taire.
	if _sonne <= 0.0:
		_raccrocher()
	queue_redraw()


func _repondre() -> void:
	_decroche = true
	_sonne = 0.0
	_lecteur.stop()
	# ON DEMARRE UN VRAI DIALOGUE, et ca regle deux choses d'un coup.
	#
	# Le joueur ENTEND Skyler au lieu de voir un message disparaitre. Et le
	# controleur, qui tourne APRES nous dans l'arbre, voit alors un dialogue en
	# cours : il rend la main au dialogue au lieu de lire ce meme F comme un
	# « descendre de voiture ». Sans ca, decrocher ejectait Walter de sa voiture.
	if _dialogue != null and conversation != "":
		_en_appel = true
		if not _dialogue.termine.is_connected(_sur_fin_appel):
			_dialogue.termine.connect(_sur_fin_appel)
		_dialogue.demarrer(conversation)
	queue_redraw()


# On n'a pas repondu. Le compteur bouge, RIEN NE L'ANNONCE : c'est ce qui fait
# mal, et c'est la meme regle que partout ailleurs dans ce jeu.
func _raccrocher() -> void:
	_sonne = 0.0
	_lecteur.stop()
	if not _decroche and cout_ignore > 0:
		var famille := Famille.courante(self)
		if famille != null:
			famille.ajouter(-cout_ignore)
	queue_redraw()


func _sur_fin_appel() -> void:
	_en_appel = false


func _a_la_bonne_etape() -> bool:
	var m := Mission.courante(self)
	return m != null and m.a_l_etape(etape)


# Est-on au volant ? On interroge le controleur plutot que de deviner : c'est
# lui qui possede l'etat, et deux sources de verite finissent par diverger.
func _au_volant() -> bool:
	return _controleur != null and bool(_controleur.call("au_volant"))


## LA TOUCHE D'INTERACTION NOUS APPARTIENT pendant la sonnerie et pendant
## l'appel. Le controleur la lit lui aussi, et au volant elle veut dire
## « descendre de voiture » : sans cette question, decrocher ejectait Walter sur
## le bas-cote. Une interface qui possede la touche le DIT, elle ne l'espere pas.
func absorbe_la_touche() -> bool:
	return _sonne > 0.0 or _en_appel


# L'INVITE PENDANT QUE CA SONNE. Deux touches, cote a cote : sans elles,
# personne ne devine que raccrocher existe — et un refus qu'on ne peut pas
# exprimer n'est pas un choix.
func _draw() -> void:
	if _sonne <= 0.0:
		return
	var police := ThemeDB.fallback_font
	var taille := 16
	var texte := "F   Decrocher        T   Raccrocher"
	var large := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, taille).x
	var ou := Vector2((size.x - large) / 2.0, size.y - 52.0)
	draw_string_outline(police, ou, texte, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			taille, 4, Color(0, 0, 0, 0.85))
	draw_string(police, ou, texte, HORIZONTAL_ALIGNMENT_LEFT, -1.0, taille,
			Color(1, 0.93, 0.75))
