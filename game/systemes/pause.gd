# Le menu pause.
#
# Quatre lignes : Reprendre, Options, Recommencer la mission, Quitter. Et un
# sous-menu d'options ou l'on regle les volumes.
#
# DESSINE, comme la roue, le telephone et la cachette, et pour la meme raison
# qu'eux : toute l'interface de ce jeu vit dans le SubViewport de rendu, a
# 512 x 384. Un menu fait de Button et de VBoxContainer serait net au milieu
# d'une image qui ne l'est pas, et se lirait immediatement comme un jeu
# moderne. Le prix a payer est de dessiner soi-meme le curseur ; il est faible.
#
# ON SCRUTE LES TOUCHES, on n'ecoute pas les evenements. Godot ne propage
# aucune entree dans un SubViewport : un _unhandled_input y serait
# silencieusement mort. C'est le piege qui avait rendu la roue des outils
# inutilisable, et il vaut ici aussi.
class_name Pause
extends Control

## Demande de recommencer la mission depuis le debut.
signal recommencer_demande

@export var reglages: Reglages

## Ou ecrire la partie en quittant. Facultatif : sans lui, Quitter quitte sans
## sauver, ce qui reste correct - juste sans reprise.
@export var sauvegarde: NodePath

## Les outils de test. Facultatif : sans eux, la ligne disparait du menu.
@export var dev: NodePath

## Ou l'on est dans le menu.
enum Vue { FERME, RACINE, OPTIONS, OUTILS, LIEUX }

## Combien de lieux on montre a la fois. Il y en a quarante et un et le cadre en
## tient quatorze : la liste defile autour de la ligne choisie plutot que de
## deborder de l'ecran.
const LIEUX_VISIBLES := 14

## Les lignes de la racine, dans l'ordre d'affichage.
##
## ON DECIDE SUR L'ETIQUETTE, PAS SUR LE RANG. _valider() lisait un numero de
## ligne : inserer une entree au milieu deplacait silencieusement « Quitter »
## sur « Recommencer la mission ». Une liste de menu est faite pour bouger.
const LIGNES := ["Reprendre", "Options", "Outils de test",
	"Recommencer la mission", "Quitter"]

## Les curseurs d'options : etiquette, et champ de Reglages qu'ils pilotent.
##
## Les VOLUMES d'abord, parce que c'est ce qu'on vient chercher. La vitesse du
## temps ensuite : elle est a zero par defaut — l'heure est figee — et c'est le
## seul moyen de voir le cycle jour/nuit sans ouvrir l'editeur. C'est un
## reglage de developpement assume, et le ticket en demandait la place.
const CURSEURS := [
	["Volume general", "volume_maitre", -40.0, 6.0, 1.0],
	["Effets", "volume_effets", -40.0, 6.0, 1.0],
	["Musique", "volume_musique", -40.0, 6.0, 1.0],
	["Ambiance", "volume_ambiance", -40.0, 6.0, 1.0],
	["Voix et interface", "volume_interface", -40.0, 6.0, 1.0],
	["Vitesse du temps", "temps_vitesse", 0.0, 1.0, 0.005],
]

var _vue: int = Vue.FERME
var _choix: int = 0
var _audio: Audio
var _sauvegarde: Sauvegarde
var _dev: Dev

## Ce que le dernier outil a repondu, et le temps qu'il reste a l'afficher. Un
## outil qui agit sans rien dire laisse croire qu'il n'a rien fait, et on appuie
## trois fois.
var _echo := ""
var _echo_restant := 0.0
const ECHO_DUREE := 2.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le menu doit vivre quand tout le reste est suspendu : c'est lui qui
	# suspend, et un noeud fige ne peut plus se rouvrir.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_sauvegarde = get_node_or_null(sauvegarde) as Sauvegarde
	_dev = get_node_or_null(dev) as Dev


## Les lignes reellement affichees a la racine : sans outils cables, « Outils de
## test » n'a pas lieu d'etre propose.
func _lignes() -> Array:
	if _dev != null:
		return LIGNES
	var sortie: Array = []
	for l in LIGNES:
		if l != "Outils de test":
			sortie.append(l)
	return sortie


## Le nombre de lignes du menu des outils : celles de Dev, plus « Retour ».
func _taille_outils() -> int:
	return (_dev.nombre() + 1) if _dev != null else 1


func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio


func ouverte() -> bool:
	return _vue != Vue.FERME


## Ouvre le menu et SUSPEND l'arbre. La souris est rendue : on est dans un
## menu, on ne vise plus rien.
func ouvrir() -> void:
	if _vue != Vue.FERME:
		return
	_vue = Vue.RACINE
	_choix = 0
	_neuf = true
	_calme = CALME
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	if _son() != null:
		_son().bruit("roue_ouvre")


## Ouvre directement le menu des outils. Sert aux captures et aux tests : y
## arriver a la touche suppose de traverser la racine, et la ligne selectionnee
## depend alors d'ou se trouve le curseur — qu'on ne maitrise pas dans une
## fenetre de capture.
func ouvrir_les_outils() -> void:
	ouvrir()
	if _dev == null:
		return
	_vue = Vue.OUTILS
	_choix = 0
	_echo_restant = 0.0


## Ouvre directement la liste des lieux, pour les memes raisons.
func ouvrir_les_lieux() -> void:
	ouvrir_les_outils()
	if _vue == Vue.OUTILS:
		_vue = Vue.LIEUX


func fermer() -> void:
	if _vue == Vue.FERME:
		return
	_vue = Vue.FERME
	visible = false
	_ferme_a_l_instant = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _son() != null:
		_son().bruit("roue_ferme")


## Vrai pendant l'image ou le menu vient de s'ouvrir.
##
## Le controleur ouvre sur Echap, dans son _process. Le menu tourne, lui,
## quel que soit l'etat de l'arbre : si Godot le traite apres le controleur
## dans la meme image, il relit le MEME appui et se referme aussitot. Le menu
## clignotait sans jamais rester. Une image d'attente suffit.
var _neuf: bool = false

## Vrai pendant l'image ou le menu vient de se fermer, et consomme par qui le
## lit. C'est le symetrique exact de `_neuf`, et il repare le meme genre de
## defaut dans l'autre sens.
##
## « Reprendre » se valide avec F. Le menu se ferme, releve la pause, et le
## controleur — qui vit plus bas dans l'arbre, donc traite APRES — relit le
## MEME appui dans la MEME image. Il y voyait une interaction ordinaire : on
## sortait du menu et on franchissait la porte devant laquelle on se tenait,
## teleporte a l'autre bout de la carte sans avoir rien demande.
var _ferme_a_l_instant: bool = false


## A-t-on ferme le menu a l'instant ? La reponse ne vaut qu'une fois : celui
## qui la lit consomme le drapeau, sinon un second lecteur ignorerait aussi
## l'image suivante.
func vient_de_fermer() -> bool:
	var oui := _ferme_a_l_instant
	_ferme_a_l_instant = false
	return oui


func _process(delta: float) -> void:
	if _vue == Vue.FERME:
		return
	if _neuf:
		_neuf = false
		# On note ou est le curseur SANS le suivre : sinon le tout premier
		# releve se compare a un point d'avant l'ouverture, passe pour un
		# mouvement, et vole la ligne choisie — precisement ce qu'on evite.
		_souris_avant = _souris()
		queue_redraw()
		return
	if _echo_restant > 0.0:
		_echo_restant = maxf(0.0, _echo_restant - delta)
	_naviguer(delta)
	# Apres le clavier : une ligne survolee doit gagner sur une ligne
	# selectionnee, sinon la selection saute entre les deux.
	_suivre_la_souris()
	queue_redraw()


func _taille() -> int:
	match _vue:
		Vue.RACINE:
			return _lignes().size()
		Vue.OUTILS:
			return _taille_outils()
		Vue.LIEUX:
			return (_dev.lieux().size() + 1) if _dev != null else 1
	return CURSEURS.size()


func _naviguer(delta: float) -> void:
	var taille := _taille()

	# ECHAP FERME LE MENU, D'OU QU'ON SOIT.
	#
	# Il ramenait des options vers la racine, ce qui est l'usage habituel d'un
	# menu a etages. Mais celui-ci n'a que deux etages et une seule raison
	# d'exister : reprendre la partie. Devoir presser Echap deux fois pour
	# revenir au jeu, depuis un ecran de reglages ou l'on n'a rien a valider,
	# est une marche de plus vers la sortie.
	if Input.is_action_just_pressed("ui_cancel"):
		fermer()
		return

	var bouge := 0
	if Input.is_action_just_pressed("frein"):
		bouge = 1
	elif Input.is_action_just_pressed("gaz"):
		bouge = -1
	if bouge != 0:
		_choix = (_choix + bouge + taille) % taille
		if _son() != null:
			_son().bruit("roue_cran")

	if _vue == Vue.OPTIONS:
		_regler_en_continu(delta)
		if Input.is_action_just_pressed("interagir"):
			_revenir_a_la_racine("Options")
		return

	if _vue == Vue.OUTILS:
		# PAS DE REPETITION ICI, contrairement aux volumes : un choix compte
		# trois valeurs, pas quarante-six crans. Maintenir la touche ferait
		# defiler la liste entiere sur un appui un peu long.
		var sens := 0
		if Input.is_action_just_pressed("droite"):
			sens = 1
		elif Input.is_action_just_pressed("gauche"):
			sens = -1
		if sens != 0 and _dev != null and _choix < _dev.nombre():
			_dev.regler(_choix, sens)
			if _son() != null:
				_son().bruit("roue_cran")
		if Input.is_action_just_pressed("interagir"):
			_agir_sur_l_outil()
		return

	if _vue == Vue.LIEUX:
		if Input.is_action_just_pressed("interagir"):
			_aller_au_lieu()
		return

	if Input.is_action_just_pressed("interagir"):
		_valider()


# F sur la liste des lieux. On FERME derriere soi : on s'y teleporte pour aller
# regarder quelque chose, et rester devant un menu qui recouvre l'endroit ou
# l'on vient d'arriver n'a aucun sens.
func _aller_au_lieu() -> void:
	if _son() != null:
		_son().bruit("roue_cran")
	var noms := _dev.lieux() if _dev != null else []
	if _dev == null or _choix >= noms.size():
		_vue = Vue.OUTILS
		_choix = 0
		return
	_dev.aller_a(str(noms[_choix]))
	fermer()


func _revenir_a_la_racine(depuis: String) -> void:
	_vue = Vue.RACINE
	_choix = maxi(0, _lignes().find(depuis))
	_echo_restant = 0.0


# F sur une ligne du menu des outils. La derniere ligne est « Retour » et
# appartient au menu, pas a Dev : celui-ci n'a pas a savoir qu'il est affiche.
func _agir_sur_l_outil() -> void:
	if _son() != null:
		_son().bruit("roue_cran")
	if _dev == null or _choix >= _dev.nombre():
		_revenir_a_la_racine("Outils de test")
		return
	if _dev.genre(_choix) == Dev.PAGE:
		_vue = Vue.LIEUX
		_choix = 0
		_echo_restant = 0.0
		return
	_echo = _dev.agir(_choix)
	_echo_restant = ECHO_DUREE if _echo != "" else 0.0


# ------------------------------------------------------------------- souris
#
# LE MENU SE CLIQUE, parce qu'il rend le curseur.
#
# Ouvrir le menu libere la souris — on n'est plus en train de viser. Un curseur
# visible sur une liste de choix demande a etre utilise, et ne rien pouvoir
# cliquer se lit comme une interface cassee plutot que comme un parti pris.
#
# LES RECTANGLES SONT CALCULES LA OU ILS SONT DESSINES, et gardes. Recalculer
# la mise en page a deux endroits — une fois pour peindre, une fois pour
# cliquer — c'est se garantir qu'ils divergeront au premier ajustement de
# marge, et un bouton qui ne repond pas trois pixels a cote est le pire des
# defauts a diagnostiquer.
var _zones: Array[Rect2] = []
var _clic_avant: bool = false

## Quelle ligne chaque zone represente, quand la liste DEFILE : la troisieme
## zone dessinee n'est plus la troisieme entree. Vide ailleurs, ou la zone et
## l'entree portent le meme rang.
var _rangs: Array[int] = []


func _rang_de_zone(i: int) -> int:
	return _rangs[i] if i < _rangs.size() else i


# ON SCRUTE LA SOURIS, on n'ecoute pas _gui_input.
#
# Toute l'interface vit dans le SubViewport de rendu, affiche par un simple
# TextureRect. Godot ne propage aucune entree la-dedans — seul un
# SubViewportContainer le ferait — donc un _gui_input y serait silencieusement
# mort. C'est le meme piege que pour les touches, deja documente en tete de ce
# fichier et dans systemes/roue.gd.
#
# La position se convertit a la main : le curseur est en pixels de FENETRE,
# les zones en pixels de rendu (512 x 384). L'ecran couvre la fenetre entiere,
# donc le rapport suffit.
func _souris() -> Vector2:
	var fenetre := get_tree().root
	var taille := Vector2(fenetre.size)
	if taille.x <= 0.0 or taille.y <= 0.0:
		return Vector2(-1.0, -1.0)
	return fenetre.get_mouse_position() / taille * size


## Ou etait le curseur a l'image precedente. Sert a savoir s'il a BOUGE.
var _souris_avant := Vector2(-9999.0, -9999.0)

## Images pendant lesquelles on ne suit pas encore le curseur apres l'ouverture.
##
## La position du curseur est relative a la FENETRE : tant que celle-ci se place
## — elle s'ouvre sur le second ecran — chaque deplacement de fenetre se lit
## comme un deplacement de souris. Une capture s'ouvrait ainsi sur son
## quarante-quatrieme nom. Un dixieme de seconde suffit, et personne ne vise une
## ligne aussi vite.
const CALME := 6
var _calme := 0


func _suivre_la_souris() -> void:
	var p := _souris()
	if _calme > 0:
		_calme -= 1
		_souris_avant = p
		return
	# LE SURVOL NE COMPTE QUE SI LE CURSEUR BOUGE. Le menu s'ouvre la ou le
	# curseur se trouvait deja : sans cette condition, une souris posee au hasard
	# au milieu de l'ecran vole la ligne choisie a l'instant de l'ouverture, et
	# la premiere entree n'est jamais celle qu'on croit.
	var bouge := p.distance_squared_to(_souris_avant) > 1.0
	_souris_avant = p
	var zone := _zone_sous(p)
	var vise := _rang_de_zone(zone) if zone >= 0 else -1
	if bouge and vise >= 0 and vise != _choix:
		_choix = vise
		if _son() != null:
			_son().bruit("roue_cran")

	var clic := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var appui := clic and not _clic_avant
	_clic_avant = clic
	if not appui or vise < 0:
		return
	if _vue == Vue.RACINE:
		_valider()
	elif _vue == Vue.LIEUX:
		_aller_au_lieu()
	elif _vue == Vue.OUTILS:
		# Un choix se clique comme un curseur — moitie gauche, moitie droite ;
		# tout le reste est un geste, donc un simple clic.
		if _dev != null and vise < _dev.nombre() and _dev.genre(vise) == Dev.CHOIX:
			_dev.regler(vise, 1 if p.x > _zones[vise].get_center().x else -1)
			if _son() != null:
				_son().bruit("roue_cran")
		else:
			_agir_sur_l_outil()
	else:
		# Sur un curseur, on clique la VALEUR : la moitie gauche baisse, la
		# droite monte. Faire glisser demanderait de suivre le bouton entre
		# deux images, pour un reglage qui se prend par crans de toute facon.
		_regler(vise, 1 if p.x > _zones[vise].get_center().x else -1)


func _zone_sous(point: Vector2) -> int:
	for i in _zones.size():
		if _zones[i].has_point(point):
			return i
	return -1


## Cadence de repetition quand on MAINTIENT gauche ou droite, en crans par
## seconde. Le premier cran part a l'appui ; les suivants s'enchainent apres un
## temps mort, sinon un appui bref en lance deux.
const REPETITION := 14.0
const AVANT_REPETITION := 0.32

var _tenu: float = -1.0


# Regler un volume par crans d'un decibel demande quarante-six appuis pour
# traverser la plage. On maintient donc, et ca defile — c'est ce que fait
# n'importe quel curseur, et l'absence de repetition se remarque tout de suite.
func _regler_en_continu(delta: float) -> void:
	var sens := 0
	if Input.is_action_pressed("droite"):
		sens = 1
	elif Input.is_action_pressed("gauche"):
		sens = -1

	if sens == 0:
		_tenu = -1.0
		return

	if _tenu < 0.0:
		_regler(_choix, sens)
		_tenu = 0.0
		return

	var avant := _tenu
	_tenu += delta
	if _tenu < AVANT_REPETITION:
		return
	# Combien de crans se sont ecoules depuis la derniere image. On compte les
	# crans plutot que d'en passer un par image : la cadence ne doit pas
	# dependre du nombre d'images par seconde.
	var crans := int(_tenu * REPETITION) - int(maxf(avant, AVANT_REPETITION)
			* REPETITION)
	for _i in maxi(0, crans):
		_regler(_choix, sens)


func _valider() -> void:
	if _son() != null:
		_son().bruit("roue_cran")
	var lignes := _lignes()
	match str(lignes[_choix]) if _choix < lignes.size() else "":
		"Reprendre":
			fermer()
		"Options":
			_vue = Vue.OPTIONS
			_choix = 0
		"Outils de test":
			_vue = Vue.OUTILS
			_choix = 0
			_echo_restant = 0.0
		"Recommencer la mission":
			# On ferme AVANT d'annoncer : la remise en place deplace le joueur
			# et rejoue une ambiance, et faire ca sur un arbre suspendu laisse
			# la moitie du travail en attente jusqu'a la reprise.
			fermer()
			recommencer_demande.emit()
		"Quitter":
			# On sauve AVANT de quitter : c'est le moment ou l'on part avec son
			# argent, son chapeau et son heure, et ou l'on veut les retrouver.
			if _sauvegarde:
				_sauvegarde.sauver()
			get_tree().quit()


# Un cran de reglage, applique tout de suite.
#
# Les volumes passent par appliquer_volumes() du systeme audio, qui relit la
# ressource : c'est deja le chemin qu'emprunte un reglage change dans
# l'editeur, projet lance. On ne double pas le mecanisme, on s'en sert.
func _regler(i: int, sens: int) -> void:
	if reglages == null:
		return
	var c: Array = CURSEURS[i]
	var champ := str(c[1])
	var bas := float(c[2])
	var haut := float(c[3])
	var pas := float(c[4])
	reglages.set(champ, clampf(float(reglages.get(champ)) + float(sens) * pas,
			bas, haut))
	if _son() != null:
		_son().bruit("roue_cran")
	if champ.begins_with("volume_") and _son() != null:
		_son().appliquer_volumes()


# ------------------------------------------------------------------- dessin


func _draw() -> void:
	if _vue == Vue.FERME:
		return
	var police := get_theme_default_font()
	if police == null:
		return

	# Un voile sur tout l'ecran : le jeu est arrete, il faut que ca se voie.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.72))

	# Chaque page repart de zones vierges, et surtout de rangs vierges : une
	# correspondance zone-vers-ligne laissee par la liste defilante ferait
	# cliquer a cote sur la page suivante.
	_zones.clear()
	_rangs.clear()
	match _vue:
		Vue.RACINE:
			_dessiner_racine(police)
		Vue.OUTILS:
			_dessiner_outils(police)
		Vue.LIEUX:
			_dessiner_lieux(police)
		_:
			_dessiner_options(police)


func _dessiner_racine(police: Font) -> void:
	var lignes := _lignes()
	var l := 200.0
	var h := 30.0 + float(lignes.size()) * 22.0 + 18.0
	var coin := Vector2((size.x - l) / 2.0, size.y * 0.5 - h / 2.0)
	_cadre(coin, Vector2(l, h))

	_ecrire(police, "PAUSE", coin + Vector2(l / 2.0, 20.0), 15,
			Color(0.949, 0.776, 0.42), true)
	_zones.clear()
	for i in lignes.size():
		_zones.append(Rect2(coin + Vector2(8.0, 32.0 + float(i) * 22.0),
				Vector2(l - 16.0, 20.0)))
		var vise := i == _choix
		# Un chevron, pas une couleur : deux teintes proches ne se distinguent
		# pas a cette resolution, un caractere en plus se voit toujours.
		_ecrire(police, ("> " if vise else "   ") + str(lignes[i]),
				coin + Vector2(24.0, 44.0 + float(i) * 22.0), 13,
				Color(0.949, 0.925, 0.867) if vise else Color(0.68, 0.66, 0.62),
				false)
	_ecrire(police, "W / S ou la souris      F   valider      Echap   fermer",
			coin + Vector2(l / 2.0, h - 6.0), 9, Color(0.62, 0.60, 0.56), true)


func _dessiner_options(police: Font) -> void:
	var l := 260.0
	var h := 30.0 + float(CURSEURS.size()) * 20.0 + 18.0
	var coin := Vector2((size.x - l) / 2.0, size.y * 0.5 - h / 2.0)
	_cadre(coin, Vector2(l, h))

	_ecrire(police, "OPTIONS", coin + Vector2(l / 2.0, 20.0), 15,
			Color(0.949, 0.776, 0.42), true)

	_zones.clear()
	for i in CURSEURS.size():
		var c: Array = CURSEURS[i]
		var vise := i == _choix
		var y := 42.0 + float(i) * 20.0
		_zones.append(Rect2(coin + Vector2(8.0, y - 13.0),
				Vector2(l - 16.0, 18.0)))
		var teinte := Color(0.949, 0.925, 0.867) if vise \
				else Color(0.68, 0.66, 0.62)
		_ecrire(police, ("> " if vise else "   ") + str(c[0]),
				coin + Vector2(14.0, y), 12, teinte, false)

		# Une jauge plutot qu'un nombre : les decibels ne veulent rien dire a
		# l'oeil, et « -12,5 » demande de savoir que le silence est a -40.
		var valeur := float(reglages.get(str(c[1]))) if reglages != null else 0.0
		var part := clampf((valeur - float(c[2]))
				/ maxf(0.001, float(c[3]) - float(c[2])), 0.0, 1.0)
		var jauge := Rect2(coin + Vector2(l - 92.0, y - 8.0), Vector2(78.0, 8.0))
		draw_rect(jauge, Color(0.043, 0.055, 0.086, 0.85))
		draw_rect(Rect2(jauge.position, Vector2(jauge.size.x * part,
				jauge.size.y)), Color(0.60, 0.82, 0.44, 0.9 if vise else 0.55))
		draw_rect(jauge, Color(0.36, 0.35, 0.32, 0.8), false, 1.0)

	_ecrire(police, "A / D maintenus   regler      F   retour      Echap   fermer",
			coin + Vector2(l / 2.0, h - 6.0), 9, Color(0.62, 0.60, 0.56), true)


# LE MENU DES OUTILS. Une ligne par geste, la valeur a droite quand il y en a
# une, et « Retour » en dernier. Il est plus large que les autres : les
# etiquettes y sont des phrases, pas des mots.
func _dessiner_outils(police: Font) -> void:
	var n := _taille_outils()
	var l := 300.0
	var pas := 17.0
	var h := 30.0 + float(n) * pas + 26.0
	var coin := Vector2((size.x - l) / 2.0, size.y * 0.5 - h / 2.0)
	_cadre(coin, Vector2(l, h))

	_ecrire(police, "OUTILS DE TEST", coin + Vector2(l / 2.0, 20.0), 15,
			Color(0.949, 0.776, 0.42), true)

	_zones.clear()
	for i in n:
		var vise := i == _choix
		var y := 40.0 + float(i) * pas
		_zones.append(Rect2(coin + Vector2(8.0, y - 11.0), Vector2(l - 16.0, pas)))
		var teinte := Color(0.949, 0.925, 0.867) if vise \
				else Color(0.68, 0.66, 0.62)
		var etiquette := "Retour" if _dev == null or i >= _dev.nombre() \
				else _dev.nom(i)
		_ecrire(police, ("> " if vise else "   ") + etiquette,
				coin + Vector2(12.0, y), 11, teinte, false)
		if _dev == null or i >= _dev.nombre():
			continue
		var valeur := _dev.valeur(i)
		if valeur == "":
			continue
		# Les chevrons disent que ca se parcourt : sans eux, une valeur affichee
		# se lit comme un etat qu'on subit et personne n'essaie A ou D.
		var texte := ("< %s >" % valeur) if _dev.genre(i) == Dev.CHOIX else valeur
		_ecrire(police, texte, coin + Vector2(l - 14.0, y), 11,
				Color(0.60, 0.82, 0.44) if vise else Color(0.50, 0.62, 0.42),
				false, true)

	# L'echo de la derniere action, la ou le bandeau d'aide se trouve d'habitude
	# — c'est la que l'oeil descend apres avoir appuye.
	if _echo_restant > 0.0:
		_ecrire(police, _echo, coin + Vector2(l / 2.0, h - 6.0), 10,
				Color(0.949, 0.776, 0.42), true)
	else:
		_ecrire(police, "W / S choisir    A / D regler    F   agir    Echap   fermer",
				coin + Vector2(l / 2.0, h - 6.0), 9, Color(0.62, 0.60, 0.56), true)


# LA LISTE DES LIEUX, QUI DEFILE. Quarante et un noms ne tiennent pas dans un
# cadre de 384 pixels : on montre une fenetre de quatorze lignes qui suit la
# ligne choisie, avec un reperage « 12 / 41 » — sans lui, on ne sait pas si l'on
# est au debut, au milieu ou a la fin d'une liste dont on ne voit qu'un tiers.
func _dessiner_lieux(police: Font) -> void:
	var noms := _dev.lieux() if _dev != null else []
	var total := noms.size() + 1
	var fenetre := mini(LIEUX_VISIBLES, total)
	# La fenetre suit le choix sans jamais deborder : centree tant qu'elle le
	# peut, callee en haut au debut et en bas a la fin.
	var premier := clampi(_choix - fenetre / 2, 0, maxi(0, total - fenetre))

	var l := 260.0
	var pas := 17.0
	var h := 30.0 + float(fenetre) * pas + 26.0
	var coin := Vector2((size.x - l) / 2.0, size.y * 0.5 - h / 2.0)
	_cadre(coin, Vector2(l, h))

	_ecrire(police, "ALLER A...", coin + Vector2(l / 2.0, 20.0), 15,
			Color(0.949, 0.776, 0.42), true)
	_ecrire(police, "%d / %d" % [mini(_choix + 1, noms.size()), noms.size()],
			coin + Vector2(l - 12.0, 20.0), 10, Color(0.62, 0.60, 0.56), false, true)

	for rang in range(premier, premier + fenetre):
		var i := rang - premier
		var vise := rang == _choix
		var y := 40.0 + float(i) * pas
		_zones.append(Rect2(coin + Vector2(8.0, y - 11.0), Vector2(l - 16.0, pas)))
		_rangs.append(rang)
		var etiquette := "Retour" if rang >= noms.size() else str(noms[rang])
		_ecrire(police, ("> " if vise else "   ") + etiquette,
				coin + Vector2(12.0, y), 11,
				Color(0.949, 0.925, 0.867) if vise else Color(0.68, 0.66, 0.62),
				false)

	_ecrire(police, "W / S choisir      F   s y rendre      Echap   fermer",
			coin + Vector2(l / 2.0, h - 6.0), 9, Color(0.62, 0.60, 0.56), true)


func _cadre(coin: Vector2, taille: Vector2) -> void:
	draw_rect(Rect2(coin, taille), Color(0.06, 0.06, 0.07, 0.95))
	draw_rect(Rect2(coin, taille), Color(0.36, 0.33, 0.26, 0.9), false, 1.0)


## `droite` cale le texte sur sa FIN plutot que sur son debut : une colonne de
## valeurs de longueurs differentes ne s'aligne pas autrement.
func _ecrire(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color, centre: bool, droite: bool = false) -> void:
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille).x
	var decalage := 0.0
	if centre:
		decalage = largeur / 2.0
	elif droite:
		decalage = largeur
	var p := ou - Vector2(decalage, 0.0)
	var ombre := Color(0.0, 0.0, 0.0, couleur.a)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		police.draw_string(get_canvas_item(), p + d, texte,
				HORIZONTAL_ALIGNMENT_LEFT, -1, taille, ombre)
	police.draw_string(get_canvas_item(), p, texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
