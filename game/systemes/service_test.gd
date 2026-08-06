# « Un simple service » — la mission de test des appels.
#
# Elle existe pour qu'on puisse ESSAYER le mecanisme de #31 en deux minutes,
# sans attendre que les missions 2 a 5 soient ecrites. Elle se declenche depuis
# les outils de test et ne s'insere dans aucun scenario.
#
# CE QU'ELLE MET A L'EPREUVE. Walter part porter dix dollars a Jesse au
# camping-car. En chemin, Skyler appelle : il lui faut des oeufs. Trois issues,
# et AUCUNE N'EST GRATUITE :
#
#   passer les prendre       +10 famille, -6 reputation  (on arrive en retard)
#   promettre et filer droit -10 famille, +4 reputation  (on est fiable)
#   ne pas decrocher          -5 famille,  0             (on n'a rien promis)
#
# C'est le coeur du dispositif : le detour coute du TEMPS, et le retard coute de
# la reputation. Sans ce cout, prendre les oeufs serait meilleur sur tous les
# plans — et un choix sans cout n'est pas un choix (regle 2 de la direction).
# Les deux compteurs bougent en sens inverse, cote a cote a l'ecran : c'est le
# sujet du jeu rendu visible en une mission de deux minutes.
#
# RIEN N'ANNONCE LES COUTS. Les compteurs bougent, aucun message ne dit
# pourquoi, et Skyler ne redemande jamais si on a oublie. C'est ce qui fait mal.
class_name ServiceTest
extends Control

## Ou l'on en est.
enum Etape { INACTIF, EN_ROUTE, VERS_MAISON }

## Combien de temps le telephone sonne avant de renoncer, en secondes. Assez
## long pour qu'on ait le temps de decider en conduisant, assez court pour que
## ne rien faire soit une reponse.
## LA SONNERIE EST A NOUS, pas au systeme audio.
##
## Audio.bruit() fabrique un lecteur jetable et l'oublie : personne ne peut plus
## l'arreter. Le telephone continuait donc de sonner apres qu'on avait decroche,
## ce qui est exactement le contraire de ce que decrocher veut dire. On tient
## notre propre lecteur pour pouvoir le couper NET.
const SON_SONNERIE := "res://assets/sons/telephone/phone_ring.wav"

## Ce que Walter doit remettre a Jesse.
const DU := 10

const SONNERIE := 9.0

## A quelle distance on considere qu'on est arrive. Genereux : ce n'est pas une
## epreuve d'adresse, et rester bloque a deux metres du but est la pire facon
## de rater un test.
const ARRIVE := 9.0

## Apres combien de secondes AU VOLANT Skyler appelle. Le compte repart a zero
## chaque fois qu'on descend : ce sont des secondes de CONDUITE, pas des secondes
## depuis le debut de la mission. La premiere version comptait depuis le depart,
## donc l'appel tombait a l'instant ou l'on s'asseyait.
##
## On attend d'etre dans la voiture, et ce n'est pas un detail : un appel qui
## tombe pendant qu'on cherche encore ses cles se prend pour un bug. La scene
## veut Walter au volant, une main sur le telephone, deja parti — c'est la que
## la demande banale devient couteuse.
const AVANT_APPEL := 20.0

@export var joueur: NodePath
@export var desert: NodePath
@export var maison: NodePath
@export var controleur: NodePath
@export var dialogue: NodePath

var _etape: int = Etape.INACTIF
var _joueur: Node3D
var _desert: Node
var _maison: Node3D
var _bourse: Bourse
var _famille: Famille
var _reputation: Reputation
var _audio: Audio
var _controleur: Node
var _dialogue: Dialogue
var _lecteur: AudioStreamPlayer

var _depuis: float = 0.0
var _en_appel: bool = false
var _volant_depuis: float = 0.0
var _sonne: float = 0.0
var _appel_fait: bool = false
var _decroche: bool = false
var _oeufs: bool = false
var _vu_jesse: bool = false


func _ready() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joueur = get_node_or_null(joueur) as Node3D
	_desert = get_node_or_null(desert)
	_maison = get_node_or_null(maison) as Node3D
	_controleur = get_node_or_null(controleur)
	_dialogue = get_node_or_null(dialogue) as Dialogue
	_lecteur = AudioStreamPlayer.new()
	_lecteur.bus = "Interface"
	_lecteur.stream = ResourceLoader.load(SON_SONNERIE) as AudioStream
	add_child(_lecteur)
	set_process(true)
	call_deferred("_brancher")


func _brancher() -> void:
	_bourse = Bourse.courante(self)
	_famille = Famille.courante(self)
	_reputation = Reputation.courante(self)
	_audio = Audio.courant(self)
	# L'EPICERIE NOUS PREVIENT ELLE-MEME. On ne compare pas des positions pour
	# savoir si le joueur a fait ses courses : le point d'interaction le sait, et
	# c'est lui qui le dit. Une seconde source de verite finirait par diverger.
	for n in get_tree().get_nodes_in_group(Point.GROUPE):
		var p := n as Point
		if p != null and p.evenement == "courses" \
				and not p.utilise.is_connected(_sur_courses):
			p.utilise.connect(_sur_courses)


func en_cours() -> bool:
	return _etape != Etape.INACTIF


## Lance la mission de test. Appele par les outils de test.
func demarrer() -> String:
	if _joueur == null:
		return "pas de joueur"
	_etape = Etape.EN_ROUTE
	_depuis = 0.0
	_sonne = 0.0
	_appel_fait = false
	_decroche = false
	_oeufs = false
	_en_appel = false
	_volant_depuis = 0.0
	_vu_jesse = false
	queue_redraw()
	return "prends la voiture"


## Abandonne en cours de route, sans rien solder.
func arreter() -> String:
	_etape = Etape.INACTIF
	_sonne = 0.0
	queue_redraw()
	return "service abandonne"


func _sur_courses(_p: Point) -> void:
	if _etape != Etape.INACTIF:
		_oeufs = true


func _process(delta: float) -> void:
	if _etape == Etape.INACTIF or _joueur == null:
		return
	_depuis += delta
	# LE COMPTE REPART A ZERO DES QU'ON DESCEND. Ce sont des secondes de
	# CONDUITE : la premiere version comptait depuis le debut de la mission, donc
	# le telephone sonnait a l'instant precis ou l'on s'asseyait au volant.
	_volant_depuis = (_volant_depuis + delta) if _au_volant() else 0.0

	# LA SONNERIE. Decrocher est une touche, ne rien faire en est une aussi :
	# c'est la seule facon que le silence soit une reponse et pas un oubli
	# d'interface.
	if _sonne > 0.0:
		_sonne = maxf(0.0, _sonne - delta)
		# La sonnerie s'arrete aussi quand personne ne repond : un telephone qui
		# sonne dans le vide finit toujours par se taire.
		if _sonne <= 0.0:
			_lecteur.stop()
		if Input.is_action_just_pressed("interagir"):
			_decroche = true
			_sonne = 0.0
			# ON DEMARRE UN VRAI DIALOGUE, et ca regle deux choses d'un coup.
			#
			# Le joueur ENTEND Skyler au lieu de voir un message disparaitre — il
			# avait decroche sans que rien ne se passe. Et le controleur, qui tourne
			# APRES nous dans l'arbre, voit alors un dialogue en cours : il rend la
			# main au dialogue au lieu de lire ce meme F comme un « descendre de
			# voiture ». Sans ca, decrocher ejectait Walter de sa voiture.
			_lecteur.stop()
			if _dialogue != null:
				_en_appel = true
				if not _dialogue.termine.is_connected(_sur_fin_appel):
					_dialogue.termine.connect(_sur_fin_appel)
				_dialogue.demarrer("mission_skyler_oeufs")
	elif not _appel_fait and _volant_depuis > AVANT_APPEL:
		_appel_fait = true
		_sonne = SONNERIE
		_lecteur.play()

	# LE DESERT EST UNE DESTINATION, PAS UNE CONDITION.
	#
	# On y va porter dix dollars a Jesse, et c'est le trajet qui donne son sens a
	# l'appel. Mais rentrer chez soi solde la mission QUOI QU'IL ARRIVE : la
	# premiere version bloquait tant qu'on n'avait pas touche le camping-car, ce
	# qui transformait une scene en corvee. On propose un but, on n'enferme pas.
	if not _vu_jesse and _distance(_arrivee_desert()) < ARRIVE:
		_vu_jesse = true
		if _bourse != null:
			_bourse.retirer(DU)
		_etape = Etape.VERS_MAISON
	if _maison != null and _distance(_maison.global_position) < ARRIVE:
		_solder()
	queue_redraw()


# Est-on au volant ? On interroge le controleur plutot que de deviner : c'est
# lui qui possede l'etat, et deux sources de verite finissent par diverger.
func _au_volant() -> bool:
	return _controleur != null and bool(_controleur.call("au_volant"))


func _sur_fin_appel() -> void:
	_en_appel = false


## LA TOUCHE D'INTERACTION NOUS APPARTIENT pendant la sonnerie et pendant
## l'appel. Le controleur la lit lui aussi, et au volant elle veut dire
## « descendre de voiture » : sans cette question, decrocher ejectait Walter sur
## le bas-cote. C'est le meme mecanisme que pour le menu pause et la cachette —
## une interface qui possede la touche le DIT, elle ne l'espere pas.
func absorbe_la_touche() -> bool:
	return _etape != Etape.INACTIF and (_sonne > 0.0 or _en_appel)


func _arrivee_desert() -> Vector3:
	if _desert != null and _desert.has_method("arrivee"):
		return _desert.call("arrivee")
	return Vector3.INF


func _distance(ou: Vector3) -> float:
	return _joueur.global_position.distance_to(ou) if ou != Vector3.INF else 9999.0


# LE SOLDE, EN SILENCE. Aucun message, aucun bilan, aucune ligne de dialogue :
# les deux compteurs bougent, et le joueur comprend ou ne comprend pas. C'est ce
# que le ticket demande — « trois couts, jamais annonces » — et c'est encore
# tenable maintenant qu'ils sont affiches, precisement parce que rien ne les
# commente.
func _solder() -> void:
	_etape = Etape.INACTIF
	_sonne = 0.0
	if _oeufs:
		# ON N'AJOUTE RIEN A LA FAMILLE ICI : l'epicerie l'a deja fait quand on
		# s'y est arrete. Le compter une seconde fois donnerait +20 pour un seul
		# geste, et surtout ferait mentir le compteur — il aurait bouge deux fois
		# pour la meme chose. Ce que la mission ajoute, c'est le COUT : on arrive
		# en retard, et le retard se paie en reputation.
		if _reputation != null:
			_reputation.tant_pis("livraison_ratee")
	elif _decroche:
		if _famille != null:
			_famille.ajouter(-10)
		if _reputation != null:
			_reputation.merci("livraison")
	else:
		if _famille != null:
			_famille.ajouter(-5)
	queue_redraw()


## Ce qui s'est passe, pour les tests headless : on ne peut pas lire une
## consequence silencieuse autrement.
func journal() -> String:
	return "oeufs=%s decroche=%s etape=%d" % [str(_oeufs), str(_decroche), _etape]


func _draw() -> void:
	if _etape == Etape.INACTIF:
		return
	var police := get_theme_default_font()
	if police == null:
		return

	var texte := "Porter 10 $ a Jesse, au camping-car" if _etape == Etape.EN_ROUTE \
			else "Rentrer chez soi"
	_ecrire(police, texte, Vector2(size.x / 2.0, 62.0), 11,
			Color(0.62, 0.60, 0.56))

	if _sonne > 0.0:
		# La sonnerie couvre l'objectif : c'est elle qui demande une decision,
		# et deux textes qui se disputent l'attention n'en laissent lire aucun.
		_ecrire(police, "Skyler appelle", Vector2(size.x / 2.0, 80.0), 14,
				Color(0.949, 0.776, 0.42))
		_ecrire(police, "F pour decrocher", Vector2(size.x / 2.0, 94.0), 10,
				Color(0.72, 0.70, 0.64))


func _ecrire(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color) -> void:
	var l := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var p := ou - Vector2(l / 2.0, 0.0)
	police.draw_string(get_canvas_item(), p + Vector2(1, 1), texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0, 0, 0, couleur.a))
	police.draw_string(get_canvas_item(), p, texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille, couleur)
