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
enum Etat { RANGE, MENU, CONTACTS, SONNE, EN_LIGNE }

const FICHIER := "res://donnees/telephone.json"

signal appel(cle: String)
signal raccroche

@export var reglages: Reglages

var _audio: Audio
var _etat: int = Etat.RANGE
var _contacts: Array = []
var _entrees: Array = []          # les lignes du menu principal
var _selection: int = 0
var _ouverture: float = 0.0       # 0 range, 1 en main — pour l'animation
var _attente: float = 0.0         # temps restant sur l'etat courant
var _appele: String = ""


func _ready() -> void:
	_audio = get_tree().get_first_node_in_group(Audio.GROUPE) as Audio
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
	print("TELEPHONE : %d contact(s)" % _contacts.size())


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
	if _audio != null:
		_audio.bruit("roue_ouvre")


func ranger() -> void:
	if _etat == Etat.RANGE:
		return
	_etat = Etat.RANGE
	_appele = ""
	if _audio != null:
		_audio.bruit("roue_ferme")
	raccroche.emit()


func _process(delta: float) -> void:
	var vers := 0.0 if _etat == Etat.RANGE else 1.0
	var pas := delta / maxf(0.01, reglages.telephone_ouverture)
	_ouverture = move_toward(_ouverture, vers, pas)
	if _etat == Etat.RANGE and _ouverture <= 0.0:
		visible = false

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
		if _audio != null:
			_audio.bruit("roue_cran")

	if Input.is_action_just_pressed("interagir"):
		_valider()


func _valider() -> void:
	if _audio != null:
		_audio.bruit("roue_cran")
	if _etat == Etat.MENU:
		_etat = Etat.CONTACTS
		_selection = 0
		return

	var fiche: Dictionary = _contacts[_selection]
	_appele = str(fiche.get("cle", ""))
	_etat = Etat.SONNE
	_attente = reglages.telephone_sonnerie
	if _audio != null:
		_audio.bruit("sonnerie")


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

	match _etat:
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


func _nom_de(cle: String) -> String:
	for c in _contacts:
		if str((c as Dictionary).get("cle", "")) == cle:
			return str((c as Dictionary).get("nom", cle.capitalize()))
	return cle.capitalize()
