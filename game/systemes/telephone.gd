# Le telephone.
#
# Un SGH-127 dessine par-dessus le jeu, comme la roue. DESSINE et pas assemble
# en noeuds, pour la meme raison qu'elle : le contenu du menu vient de
# donnees/telephone.json, et un menu fait de noeuds poses a la main devrait
# etre refait a chaque contact ajoute.
#
# Il ne connait aucun correspondant en particulier. Ajouter quelqu'un a la
# liste est une entree de JSON, et sa conversation vit dans dialogues.json
# comme toutes les autres — c'est le systeme de dialogue existant, declenche
# autrement.
class_name Telephone
extends Control

## Les etats se suivent dans l'ordre. Le clapet met un instant a s'ouvrir, la
## sonnerie dure, on parle, on raccroche : un menu qui apparaitrait
## instantanement et se fermerait sec n'aurait rien d'un telephone.
enum Etat { RANGE, MENU, CONTACTS, SONNE, EN_LIGNE, MISSION }

## Le menu « Mission » n'est pas dans donnees/telephone.json : il n'est pas
## une liste de correspondants mais une VUE sur l'etat du jeu. On le pose ici,
## en tete, parce que c'est ce qu'on vient chercher neuf fois sur dix.
const ENTREE_MISSION := "Mission"

## Combien de temps le telephone s'ouvre tout seul pour annoncer un objectif,
## en secondes. Il sort, montre, et se referme — c'est ce que demande le
## scenario, et c'est aussi ce qui evite d'interrompre le joueur.
const ANNONCE := 3.2

const FICHIER := "res://donnees/telephone.json"

signal appel(cle: String)
signal raccroche

@export var reglages: Reglages

var _audio: Audio

## Le systeme audio, retrouve A LA DEMANDE et garde ensuite.
##
## Pas dans _ready() : le noeud Audio est declare plus bas dans la scene, donc
## il n'est pas encore dans son groupe quand celui-ci s'initialise. Le chercher
## trop tot donnait null, definitivement, et le silence qui suit ressemble a un
## mecanisme pas encore branche.
func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio
var _etat: int = Etat.RANGE
var _contacts: Array = []
var _entrees: Array = []          # les lignes du menu principal
var _selection: int = 0
var _ouverture: float = 0.0       # 0 range, 1 en main — pour l'animation
var _attente: float = 0.0         # temps restant sur l'etat courant
var _appele: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charger()
	set_process(true)


func _charger() -> void:
	if not FileAccess.file_exists(FICHIER):
		push_error("telephone : %s introuvable" % FICHIER)
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(lu) != TYPE_DICTIONARY:
		push_error("telephone : %s illisible. Verifier les virgules." % FICHIER)
		return
	_contacts = (lu as Dictionary).get("contacts", [])
	_entrees = (lu as Dictionary).get("menu", ["Appeler"])
	if not _entrees.has(ENTREE_MISSION):
		_entrees.insert(0, ENTREE_MISSION)
	print("TELEPHONE : %d contact(s)" % _contacts.size())


## La mission a suivre. Facultative : sans elle le menu reste, et il est vide.
func suivre(m: Mission) -> void:
	_mission = m


## Sort le telephone pour ANNONCER l'objectif courant, puis le range tout seul.
## C'est ce que le scenario demande a chaque changement d'etape.
func annoncer() -> void:
	if _etat != Etat.RANGE:
		return
	_etat = Etat.MISSION
	_annonce = ANNONCE
	visible = true
	if _son() != null:
		_son().bruit("roue_ouvre")


## Est-on en train de s'annoncer tout seul ? Le controleur ne bloque pas le
## joueur pendant ce temps : une annonce qui immobilise trois secondes est une
## punition, pas une information.
func annonce_en_cours() -> bool:
	return _annonce > 0.0

var _mission: Mission
var _annonce: float = 0.0


func sorti() -> bool:
	return _etat != Etat.RANGE


## Le repertoire, pour le test : il verifie que chaque correspondant a bien
## une fiche de dialogue. Une cle mal orthographiee donne un appel qui sonne
## et n'aboutit jamais, sans la moindre erreur.
func contacts() -> Array:
	return _contacts


## L'entree visee, pour le test. La selection est invisible autrement qu'en
## lisant l'ecran dessine, ce qu'aucun test ne peut faire.
func selection() -> int:
	return _selection


## Est-on dans un moment ou le telephone parle tout seul ? Le controleur s'en
## sert pour ne pas laisser la touche interrompre une sonnerie en cours.
func occupe() -> bool:
	return _etat == Etat.SONNE


func sortir() -> void:
	if _etat != Etat.RANGE:
		return
	_etat = Etat.MENU
	_selection = 0
	visible = true
	if _son() != null:
		_son().bruit("roue_ouvre")


## LE TELEPHONE SONNE, ET ON DECROCHE. Rien d'autre.
##
## Un appel recu passait par sortir(), donc par le MENU : pendant que l'homme
## de Tuco parlait, le joueur pouvait remonter dans le repertoire, appeler
## quelqu'un d'autre, ou raccrocher au nez de celui qui lance la mission. Ce
## n'est pas un telephone qu'on consulte, c'est un telephone qui sonne — on le
## subit, et la seule chose a faire est de lire.
##
## L'etat EN_LIGNE est deja ignore par _naviguer(). Il suffisait d'y entrer
## directement au lieu de passer par le menu.
func decrocher(qui: String) -> void:
	if _etat != Etat.RANGE:
		return
	_etat = Etat.EN_LIGNE
	_impose = true
	_appelant = qui
	_selection = 0
	visible = true
	if _son() != null:
		_son().bruit("roue_ouvre")


## Est-ce un appel qu'on subit ? Le controleur s'en sert pour ne pas laisser
## la touche T raccrocher au milieu d'une conversation de mission.
func impose() -> bool:
	return _impose

var _impose: bool = false

## Le nom affiche sur l'ecran pendant un appel recu. Il ne vient pas du
## repertoire : celui qui appelle Walter n'y est pas, et c'est tout le sujet.
var _appelant: String = ""


func ranger() -> void:
	if _etat == Etat.RANGE:
		return
	_etat = Etat.RANGE
	_appele = ""
	_impose = false
	if _son() != null:
		_son().bruit("roue_ferme")
	raccroche.emit()


func _process(delta: float) -> void:
	var vers := 0.0 if _etat == Etat.RANGE else 1.0
	var pas := delta / maxf(0.01, reglages.telephone_ouverture)
	_ouverture = move_toward(_ouverture, vers, pas)
	if _etat == Etat.RANGE and _ouverture <= 0.0:
		visible = false

	if _annonce > 0.0:
		_annonce = maxf(0.0, _annonce - delta)
		if _annonce == 0.0 and _etat == Etat.MISSION:
			ranger()

	if _attente > 0.0:
		_attente = maxf(0.0, _attente - delta)
		if _attente == 0.0 and _etat == Etat.SONNE:
			# La sonnerie est finie : on decroche, et le dialogue prend la main.
			_etat = Etat.EN_LIGNE
			appel.emit(_appele)

	_naviguer()
	queue_redraw()


# On SCRUTE les touches, on n'ecoute pas les evenements.
#
# Toute l'interface vit dans le SubViewport de rendu, ou Godot ne propage
# aucune entree : un _unhandled_input y serait silencieusement mort. C'est le
# piege qui avait rendu la roue des outils inutilisable, et il vaut ici aussi.
func _naviguer() -> void:
	# L'ecran de mission ne se navigue pas : il se lit, et on en sort.
	if _etat == Etat.MISSION:
		if _annonce <= 0.0 and Input.is_action_just_pressed("interagir"):
			_etat = Etat.MENU
			_selection = 0
		return
	if _etat != Etat.MENU and _etat != Etat.CONTACTS:
		return

	var liste := _entrees if _etat == Etat.MENU else _contacts
	if liste.is_empty():
		return

	var bouge := 0
	if Input.is_action_just_pressed("frein"):
		bouge = 1
	elif Input.is_action_just_pressed("gaz"):
		bouge = -1
	if bouge != 0:
		_selection = (_selection + bouge + liste.size()) % liste.size()
		if _son() != null:
			_son().bruit("roue_cran")

	if Input.is_action_just_pressed("interagir"):
		_valider()


func _valider() -> void:
	if _son() != null:
		_son().bruit("roue_cran")
	if _etat == Etat.MENU:
		if str(_entrees[_selection]) == ENTREE_MISSION:
			_etat = Etat.MISSION
			return
		_etat = Etat.CONTACTS
		_selection = 0
		return

	var fiche: Dictionary = _contacts[_selection]
	_appele = str(fiche.get("cle", ""))
	_etat = Etat.SONNE
	_attente = reglages.telephone_sonnerie
	if _son() != null:
		_son().bruit("sonnerie")


func _draw() -> void:
	if _ouverture <= 0.0:
		return
	var police := get_theme_default_font()
	if police == null:
		return

	# Le combine monte depuis le bas, en bas a droite : c'est la ou une main
	# tient un telephone, et ca laisse l'ecran libre.
	var l := reglages.telephone_largeur
	var h := reglages.telephone_hauteur
	# Une marge sous le combine : pose a ras du bord, il se lit comme une image
	# coupee plutot que comme un objet tenu en main.
	var repos := size.y - 10.0
	var coin := Vector2(size.x - l - 14.0, repos - h * _ouverture)

	var corps := Rect2(coin, Vector2(l, h))
	draw_rect(corps, Color(0.09, 0.10, 0.12, 0.96))
	draw_rect(corps, Color(0.32, 0.33, 0.36, 0.9), false, 1.0)

	# L'ecran : le vert-jaune d'un ecran a cristaux liquides retroeclaire.
	var marge := 6.0
	var ecran := Rect2(coin + Vector2(marge, marge),
			Vector2(l - marge * 2.0, h * 0.52))
	draw_rect(ecran, Color(0.42, 0.52, 0.24, 0.95))
	draw_rect(ecran, Color(0.16, 0.20, 0.12, 0.9), false, 1.0)

	if _ouverture < 0.85:
		return

	var encre := Color(0.10, 0.13, 0.07)
	var y := ecran.position.y + 12.0
	var x := ecran.position.x + 5.0

	# L'HEURE, en haut a droite de l'ecran, quel que soit le menu affiche.
	#
	# C'est la premiere chose qu'on regarde sur un telephone, et le jeu n'avait
	# aucun autre endroit ou lire l'heure — alors que la mission entiere se
	# joue sur un compte a rebours de journee et que le ciel change.
	#
	# Elle est dessinee AVANT le contenu et en petit : elle ne doit jamais
	# disputer la place a ce qu'on est venu lire.
	var horloge := get_tree().get_first_node_in_group(Temps.GROUPE) as Temps
	if horloge != null:
		var heure := horloge.texte()
		var largeur := police.get_string_size(heure, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 8).x
		draw_string(police, Vector2(ecran.end.x - 4.0 - largeur, y - 4.0),
				heure, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(encre, 0.75))

	match _etat:
		Etat.MISSION:
			_ecran_de_mission(police, ecran, x, y, encre)
		Etat.SONNE:
			draw_string(police, Vector2(x, y), "Appel...",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, encre)
			draw_string(police, Vector2(x, y + 13.0), _nom_de(_appele),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, encre)
		Etat.EN_LIGNE:
			draw_string(police, Vector2(x, y), "En ligne",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, encre)
			draw_string(police, Vector2(x, y + 13.0), _nom_de(_appele),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, encre)
		_:
			var liste := _entrees if _etat == Etat.MENU else _contacts
			for i in liste.size():
				var texte: String = (str(liste[i]) if _etat == Etat.MENU
						else str((liste[i] as Dictionary).get("nom", "?")))
				var vise := i == _selection
				# Le curseur est un chevron, pas une couleur : a dix pixels de
				# haut sur un fond vert, deux teintes de vert ne se distinguent
				# pas, alors qu'un caractere en plus se voit toujours.
				draw_string(police, Vector2(x, y + float(i) * 12.0),
						("> " if vise else "  ") + texte,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, encre)

	# Le clavier, purement decoratif : trois rangees de touches suggerees.
	var t := Vector2((l - marge * 2.0 - 8.0) / 3.0, 5.0)
	for r in 3:
		for c in 3:
			draw_rect(Rect2(coin + Vector2(marge + float(c) * (t.x + 4.0),
					marge + ecran.size.y + 7.0 + float(r) * (t.y + 4.0)), t),
					Color(0.20, 0.21, 0.24, 0.95))


# L'ecran de suivi. Ce qui est fait est BARRE d'une croix, ce qui reste est
# pointe par un chevron.
#
# Une coche et une case vide auraient demande deux symboles distincts sur un
# ecran vert de dix pixels de haut, ou deux glyphes fins se confondent. Une
# croix pleine et un chevron ne se ressemblent pas, meme flous.
func _ecran_de_mission(police: Font, ecran: Rect2, x: float, y: float,
		encre: Color) -> void:
	if _mission == null:
		draw_string(police, Vector2(x, y), "Aucune mission",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, encre)
		return

	draw_string(police, Vector2(x, y), _mission.titre(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, encre)
	# Un filet sous le titre : sans lui, la liste commence sans qu'on sache
	# que c'en est une.
	draw_line(Vector2(x, y + 3.0), Vector2(ecran.end.x - 5.0, y + 3.0),
			Color(encre, 0.45), 1.0)

	if _mission.finie():
		draw_string(police, Vector2(x, y + 18.0), "Mission accomplie",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, encre)
		return

	# Les deux dernieres etapes faites, puis l'etape en cours. L'ecran fait
	# quatre lignes : tout afficher demanderait de le faire defiler, et il n'y
	# a pas de quoi lire quinze objectifs sur un telephone de 2008.
	var dispo := ecran.end.x - 5.0 - x
	var faites := _mission.faites()
	var ligne := y + 14.0
	# Une seule etape faite au lieu de deux : l'objectif COURANT tient
	# desormais sur deux ou trois lignes, et c'est lui qu'on vient lire.
	for i in range(maxi(0, faites.size() - 1), faites.size()):
		for morceau in _couper(police, "x " + str(faites[i]), 9, dispo):
			draw_string(police, Vector2(x, ligne), morceau,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(encre, 0.55))
			ligne += 10.0
	for morceau in _couper(police, "> " + _mission.objectif(), 10, dispo):
		draw_string(police, Vector2(x, ligne), morceau,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, encre)
		ligne += 11.0


# Coupe un texte en lignes qui tiennent dans la largeur donnee.
#
# L'ecran du combine fait cinquante pixels de large. « Rejoindre le labo dans le
# desert » y occupait cent soixante pixels : le texte sortait du telephone et
# continuait par-dessus le decor, ce qui donnait un objectif illisible dessine
# sur une rue. Godot sait faire du retour a la ligne dans un Label, mais cet
# ecran est DESSINE — c'est ce qui lui donne son grain — et draw_string ne
# coupe rien tout seul.
static func _couper(police: Font, texte: String, taille: int,
		largeur: float) -> Array:
	var lignes: Array = []
	var courante := ""
	for mot in texte.split(" ", false):
		var essai := mot if courante == "" else courante + " " + mot
		if police.get_string_size(essai, HORIZONTAL_ALIGNMENT_LEFT, -1,
				taille).x <= largeur or courante == "":
			courante = essai
			continue
		lignes.append(courante)
		courante = mot
	if courante != "":
		lignes.append(courante)
	return lignes


func _nom_de(cle: String) -> String:
	if _impose:
		return _appelant
	for c in _contacts:
		if str((c as Dictionary).get("cle", "")) == cle:
			return str((c as Dictionary).get("nom", cle.capitalize()))
	return cle.capitalize()
