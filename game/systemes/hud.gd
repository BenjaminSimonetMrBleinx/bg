# L'affichage tete haute.
#
# Il vit DANS le SubViewport, donc rendu a 512 x 384 comme le reste. Un texte
# net superpose a une image basse resolution trahirait immediatement un jeu
# moderne : les HUD PS2 partageaient le meme tampon que la 3D, et c'est ce
# qui leur donne ce grain.
#
# Regle de conduite : n'afficher que ce qui change. Un compteur immobile a
# l'ecran pendant qu'on marche est du bruit, pas de l'information.
class_name Hud
extends Control

@export var reglages: Reglages
@export var vehicule: NodePath
@export var equipement: NodePath
@export var controleur: NodePath
@export var joueur: NodePath
@export var tir: NodePath

## L'icone du sac de billets, livree par Guillaume et detouree par
## outils/detourer.py. Sans elle le montant s'affiche quand meme, precede d'un
## dollar : une image manquante ne doit jamais faire disparaitre l'information.
@export var icone_argent: Texture2D

## Le portrait de Walter, a gauche de sa barre de vie. Genere par
## outils/gen_textures.py, en 32 pixels : c'est sa taille d'affichage, et
## l'agrandir puis le reduire ne ferait que le rendre flou.
@export var icone_visage: Texture2D

var _v: Vehicule
var _eq: Equipement
var _c: Node
var _j: Joueur
var _tir: Tir
var _bourse: Bourse
var _famille: Famille
var _reputation: Reputation
var _mission: Mission

## Le montant AFFICHE, qui rattrape le montant reel. Voir trois cent mille
## dollars apparaitre d'un coup ne se lit pas ; les voir defiler en une
## seconde, si — et c'est la seule facon de sentir la somme.
var _affiche: float = 0.0

## Compte a rebours d'affichage de l'objectif, apres un changement d'etape.
var _objectif: float = 0.0
var _texte_objectif: String = ""

## Rouge a l'ecran quand on prend un coup. C'est le seul retour immediat : une
## barre qui descend en haut a gauche ne se voit pas quand on regarde devant.
var _douleur: float = 0.0

## Compte a rebours d'affichage du nom de l'outil, en secondes. L'objet
## equipe se voit dans la main : le nom n'a d'interet qu'a l'instant du
## changement, apres quoi il encombre.
var _annonce: float = 0.0
var _texte_annonce: String = ""

## L'objet en main. Son nom ne s'affiche qu'une seconde et demie a l'equipement
## — assez pour savoir ce qu'on vient de prendre, pas pour s'en souvenir deux
## minutes plus tard. Le rappel permanent vit en bas a gauche.
var _outil: int = -1

## Vitesse lissee. La valeur brute d'un VehicleBody3D oscille d'un ou deux
## km/h a chaque image ; affichee telle quelle, le compteur papillonne.
var _kmh: float = 0.0

## LA PALETTE DE LA SERIE, en un endroit.
##
## Breaking Bad tient dans trois couleurs : le vert-olive de la case du
## tableau periodique, l'ambre du desert, le rouge du sang. Les avoir nommees
## ici evite qu'elles derivent d'un dessin a l'autre — c'est ce qui etait en
## train d'arriver, chaque fonction ayant sa propre nuance de vert.
const BB_OLIVE := Color(0.541, 0.651, 0.243)
const BB_AMBRE := Color(0.949, 0.776, 0.420)
const BB_ROUGE := Color(0.702, 0.208, 0.161)
const COULEUR_FOND := Color(0.043, 0.055, 0.086, 0.80)


func _ready() -> void:
	_v = get_node_or_null(vehicule) as Vehicule
	_eq = get_node_or_null(equipement) as Equipement
	_c = get_node_or_null(controleur)
	_j = get_node_or_null(joueur) as Joueur
	_tir = get_node_or_null(tir) as Tir
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _eq != null:
		_eq.change.connect(_sur_changement_outil)
	if _j != null:
		_j.blesse.connect(_sur_blessure)
	# La bourse et la mission sont retrouvees APRES la construction de la
	# scene : elles se declarent dans leur groupe a leur propre _ready, qui
	# peut passer apres celui-ci.
	call_deferred("_brancher_la_mission")
	set_process(true)


func _brancher_la_mission() -> void:
	_bourse = Bourse.courante(self)
	_famille = Famille.courante(self)
	_reputation = Reputation.courante(self)
	_mission = Mission.courante(self)
	if _bourse != null:
		_affiche = float(_bourse.montant())
	if _mission != null:
		_mission.etape_changee.connect(_sur_etape)
		# La PREMIERE etape n'emet aucun changement : on y est deja. Son
		# objectif ne s'affichait donc jamais, et la partie s'ouvrait sans dire
		# ce qu'on attend du joueur.
		_sur_etape(_mission.index())


## COMBIEN DE TEMPS L'OBJECTIF RESTE A L'ECRAN, en secondes.
##
## Il tenait quatre secondes, en petit, par-dessus le decor. Sur un ecran de
## 512 pixels ou l'on est en train de traverser une rue, quatre secondes ne
## suffisent pas a lire une phrase et a decider quoi en faire — l'information
## passait avant d'avoir servi.
##
## Une minute, c'est ce que le ticket demande, et c'est aussi la duree pendant
## laquelle un objectif est encore une NOUVELLE. Apres, il vit dans le
## telephone : c'est la qu'on va le relire.
const OBJECTIF_DUREE := 60.0

## Sur combien de temps il s'efface, a la fin. Assez long pour qu'on voie qu'il
## part, assez court pour ne pas trainer.
const OBJECTIF_FONDU := 2.5


func _sur_etape(_index: int) -> void:
	if _mission == null:
		return
	_texte_objectif = _mission.objectif()
	_objectif = 0.0 if _texte_objectif == "" else OBJECTIF_DUREE


func _sur_blessure(_restant: float) -> void:
	_douleur = 1.0


func _sur_changement_outil(i: int) -> void:
	_texte_annonce = _eq.nom_de(i) if i >= 0 else "Mains vides"
	_annonce = reglages.hud_annonce
	_outil = i


func _process(delta: float) -> void:
	if _annonce > 0.0:
		_annonce = maxf(0.0, _annonce - delta)
	if _objectif > 0.0:
		_objectif = maxf(0.0, _objectif - delta)
	if _douleur > 0.0:
		_douleur = maxf(0.0, _douleur - delta * 1.6)
	if _v != null:
		var cible: float = absf(_v.vitesse_kmh())
		_kmh = lerpf(_kmh, cible, clampf(delta * 12.0, 0.0, 1.0))
	if _bourse != null:
		var somme := float(_bourse.montant())
		# Un rattrapage proportionnel a l'ECART, avec un plancher : sans le
		# plancher, les derniers dollars mettent une eternite ; sans le
		# proportionnel, trois cent mille prendraient une minute.
		var pas := maxf(absf(somme - _affiche) * 3.0, 900.0) * delta
		_affiche = move_toward(_affiche, somme, pas)
	queue_redraw()


func _au_volant() -> bool:
	# On interroge le controleur plutot que de deviner : c'est lui qui possede
	# l'etat, et deux sources de verite finissent toujours par diverger.
	return _c != null and _c.call("au_volant")


func _draw() -> void:
	var police := get_theme_default_font()
	if police == null:
		return

	_version(police)
	_bandeau(police)
	_etat_du_joueur(police)
	_objectif_courant(police)
	_objet_en_main(police)
	_reticule()

	if _au_volant():
		_compteur(police)

	if _annonce > 0.0:
		# Fondu sur le dernier tiers, pour que ca ne disparaisse pas d'un coup.
		var a := clampf(_annonce / maxf(0.01, reglages.hud_annonce * 0.33), 0.0, 1.0)
		_ecrire(police, _texte_annonce, Vector2(size.x / 2.0, size.y - 62.0),
				17, Color(0.949, 0.776, 0.42, a), true)


# Un bandeau en haut de l'ecran, quand le jeu a quelque chose a refuser ou a
# annoncer. Le texte vient du controleur : le HUD ne decide de rien, il dessine.
#
# Une bande sombre derriere, pas seulement du texte : le haut de l'ecran est
# le ciel, et un texte clair sur un ciel clair de midi ne se lit pas.
func _bandeau(police: Font) -> void:
	if _c == null:
		return
	var texte: String = _c.call("bandeau")
	if texte == "":
		return
	var a: float = _c.call("bandeau_opacite")
	var h := 22.0
	draw_rect(Rect2(Vector2(0.0, 26.0), Vector2(size.x, h)),
			Color(0.043, 0.055, 0.086, 0.72 * a))
	_ecrire(police, texte, Vector2(size.x / 2.0, 41.0), 13,
			Color(0.949, 0.925, 0.867, a), true)


# La version, en haut a droite, en permanence.
#
# C'est la seule chose affichee tout le temps, et elle enfreint donc la regle
# de conduite du fichier. La raison la vaut : quand quelqu'un envoie une
# capture d'ecran en disant que quelque chose ne marche pas, la premiere
# question est toujours « tu es sur quelle version ». Elle est maintenant sur
# l'image.
#
# Assez petite et assez pale pour disparaitre du regard — 9 points a 512 de
# large, c'est la taille d'une mention legale.
func _version(police: Font) -> void:
	_ecrire(police, Version.texte(), Vector2(size.x - 6.0, 14.0), 9,
			Color(0.72, 0.70, 0.64, 0.55), false, HORIZONTAL_ALIGNMENT_RIGHT)


# L'ETAT DU JOUEUR : son visage, sa vie, son argent. Un seul bloc.
#
# Les trois etaient dispersés : l'argent en haut a gauche, la barre de vie
# dessous et SEULEMENT quand elle n'etait pas pleine, ce qui deplacait tout au
# premier coup recu. Trois informations sur la meme personne se lisent comme
# une seule, et une interface qui bouge toute seule oblige a la relire.
#
# La barre est desormais TOUJOURS la. La regle du fichier dit de n'afficher que
# ce qui change ; celle-ci est l'exception que sa fonction justifie, comme
# l'argent et la version — on veut savoir ou l'on en est avant de pousser une
# porte, pas apres avoir pris une balle.
func _etat_du_joueur(police: Font) -> void:
	var coin := Vector2(6.0, 6.0)
	var haut := 26.0
	var x := coin.x

	if icone_visage != null:
		# Un liseré derriere le portrait : sans lui il flotte sur le decor, et
		# sur une facade claire on ne distingue plus ses contours.
		draw_rect(Rect2(coin - Vector2(1.0, 1.0),
				Vector2(icone_visage.get_width() + 2.0,
						icone_visage.get_height() + 2.0)),
				Color(0.043, 0.055, 0.086, 0.8))
		draw_texture(icone_visage, coin)
		x += icone_visage.get_width() + 5.0

	# LA BARRE DE VIE EST SEGMENTEE, comme une jauge de laboratoire.
	#
	# Elle etait un rectangle plein qui se vidait en continu. A 512 pixels de
	# large, une longueur continue ne se lit pas : on voit qu'elle a baisse,
	# jamais de combien. Douze segments se COMPTENT du coin de l'oeil, et c'est
	# ce qu'on veut d'une barre de vie — savoir combien il en reste, pas
	# regarder un degrade.
	#
	# Le segment en cours de perte reste allume a demi : sans ca la barre saute
	# par a-coups de huit pour cent et donne l'impression de mentir.
	if _j != null:
		var l := 78.0
		var h := 7.0
		var barre := Vector2(x, coin.y + 2.0)
		draw_rect(Rect2(barre, Vector2(l, h)), COULEUR_FOND)
		var part := clampf(_j.pv / 100.0, 0.0, 1.0)
		# Olive quand tout va bien, ambre, puis rouge : la couleur dit
		# l'urgence avant que le compte ne se lise.
		var teinte := BB_ROUGE.lerp(BB_AMBRE, clampf(part * 2.0, 0.0, 1.0))
		teinte = teinte.lerp(BB_OLIVE, clampf((part - 0.5) * 2.0, 0.0, 1.0))
		var n := 12
		var pas := l / float(n)
		for k in n:
			var rempli := part * n - k
			if rempli <= 0.0:
				continue
			var c := teinte
			if rempli < 1.0:
				c.a = 0.45
			draw_rect(Rect2(barre + Vector2(k * pas + 1.0, 1.0),
					Vector2(pas - 2.0, h - 2.0)), c)
		draw_rect(Rect2(barre, Vector2(l, h)), Color(0.72, 0.70, 0.64, 0.45),
				false, 1.0)

	# L'argent, sous la barre, aligne sur elle.
	if _bourse == null:
		return
	var xa := x
	var ya := coin.y + haut - 6.0
	if icone_argent != null:
		draw_texture(icone_argent, Vector2(xa, ya - 8.0))
		xa += icone_argent.get_width() + 4.0
	_ecrire(police, Bourse.ecrire(roundi(_affiche)), Vector2(xa, ya + 3.0), 13,
			BB_OLIVE, false)

	# LES POINTS DE FAMILLE, a droite de l'argent et en permanence.
	#
	# C'est le seul chiffre du jeu qui se montre — decision du 06/08/2026, voir
	# docs/12-direction.md. Il se lit d'un coup d'oeil en conduisant, donc il
	# CHANGE DE COULEUR plutot que de demander une comparaison : on ne calcule
	# pas « 22 sur 100 » au volant, on voit du rouge.
	if _famille == null:
		return
	var p := _famille.points()
	var teinte := BB_OLIVE
	if p <= 25:
		teinte = Color(0.85, 0.35, 0.22)
	elif p <= 50:
		teinte = Color(0.85, 0.62, 0.25)
	_ecrire(police, "Famille %d" % p, Vector2(xa + 74.0, ya + 3.0), 13,
			teinte, false)

	# LA REPUTATION, troisieme et dernier compteur. Elle monte quand la famille
	# descend — c'est tout le sujet du jeu, et les avoir cote a cote est ce qui
	# le donne a voir sans une ligne de dialogue.
	if _reputation == null:
		return
	var r := _reputation.points()
	_ecrire(police, "Rue %d" % r, Vector2(xa + 152.0, ya + 3.0), 13,
			BB_OLIVE if r < 60 else Color(0.95, 0.78, 0.42), false)


# L'OBJECTIF COURANT, en haut a gauche, sous l'argent.
#
# Il etait pose au milieu du bas de l'ecran, en texte nu, quatre secondes. Trois
# choses n'allaient pas et se cumulaient : le bas de l'ecran est deja occupe par
# l'invite et le cadre de dialogue, un texte sans fond se perd sur un decor
# clair, et quatre secondes ne se lisent pas.
#
# Il a maintenant sa place a lui, une bande sombre derriere, et il reste une
# minute — voir OBJECTIF_DUREE. Le petit chevron devant reprend celui du
# telephone : c'est le meme objet a deux endroits, et il doit se reconnaitre.
func _objectif_courant(police: Font) -> void:
	if _objectif <= 0.0 or _texte_objectif == "":
		return
	var a := clampf(_objectif / OBJECTIF_FONDU, 0.0, 1.0)
	var texte := "> " + _texte_objectif
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 13).x
	# Sous la bande de refus, qui occupe la largeur entiere de 26 a 48 : les
	# deux peuvent parler en meme temps, et l'un ne doit pas manger l'autre.
	var coin := Vector2(6.0, 52.0)
	draw_rect(Rect2(coin, Vector2(largeur + 12.0, 19.0)),
			Color(0.043, 0.055, 0.086, 0.66 * a))
	# Un filet ambre sur le bord gauche. C'est ce qui distingue l'objectif du
	# bandeau de refus, qui est de la meme famille de gris et vit juste au-dessus.
	draw_rect(Rect2(coin, Vector2(2.0, 19.0)), Color(0.949, 0.776, 0.42, 0.85 * a))
	_ecrire(police, texte, coin + Vector2(8.0, 13.0), 13,
			Color(0.949, 0.925, 0.867, a), false)


# LE RAPPEL DE CE QU'ON TIENT, en bas a gauche.
#
# Le nom de l'objet s'annonce une seconde et demie a l'equipement, puis
# disparait. C'est juste au moment ou l'on choisit ; ca ne l'est plus deux
# minutes apres, quand on approche de quelqu'un sans savoir si on a le
# revolver a la main. Une interface doit repondre a « qu'est-ce que je tiens »
# sans qu'on ait a rouvrir la roue pour le verifier.
#
# Discret : une case sombre et le nom en petit. On n'affiche RIEN les mains
# vides — c'est l'etat par defaut, et la regle du fichier reste de ne montrer
# que ce qui merite un coup d'oeil.
func _objet_en_main(police: Font) -> void:
	if _outil < 0 or _eq == null:
		return
	var nom := _eq.nom_de(_outil)
	if nom == "":
		return
	var largeur := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11).x
	var coin := Vector2(6.0, size.y - 24.0)
	draw_rect(Rect2(coin, Vector2(largeur + 14.0, 17.0)), COULEUR_FOND)
	# Le filet olive du bord gauche, comme l'objectif porte son filet ambre :
	# deux bandes de la meme famille de gris se distinguent par leur liseré.
	draw_rect(Rect2(coin, Vector2(2.0, 17.0)), BB_OLIVE)
	_ecrire(police, nom, coin + Vector2(9.0, 12.0), 11,
			Color(0.86, 0.85, 0.80), false)


# Le reticule, et le voile rouge des blessures.
#
# Le reticule est une CROIX OUVERTE, pas un point : un point de un pixel
# disparait sur un mur clair, et un cercle plein cache exactement ce qu'on
# vise. Quatre traits laissent le centre libre.
func _reticule() -> void:
	if _douleur > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size),
				Color(0.55, 0.06, 0.05, 0.34 * _douleur))
	if _tir == null or not _tir.vise():
		return
	var c := size / 2.0
	var couleur := Color(0.95, 0.93, 0.87, 0.85)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * 3.0, c + d * 8.0, couleur, 1.0)


func _compteur(police: Font) -> void:
	# UN CADRAN, PAS UN NOMBRE NU.
	#
	# La vitesse s'affichait en chiffres poses sur le decor. Deux choses n'y
	# allaient pas : on ne lit pas un nombre en conduisant — on regarde ou en
	# est l'aiguille — et une voiture de 2008 a un cadran, pas un afficheur.
	#
	# L'arc fait 200 degres et s'arrete a la vitesse maximale du vehicule : la
	# position de l'aiguille veut donc dire quelque chose, au lieu d'etre une
	# fraction d'un maximum invente. Le chiffre reste, petit, au centre — c'est
	# ce qu'on lit quand on veut savoir exactement.
	var centre := Vector2(size.x - 40.0, size.y - 30.0)
	var rayon := 26.0
	var depart := deg_to_rad(160.0)
	var arc := deg_to_rad(200.0)
	var maxi := 140.0
	if _v != null and _v.reglages != null:
		maxi = maxf(60.0, _v.reglages.vitesse_max_kmh)
	var part := clampf(_kmh / maxi, 0.0, 1.0)

	# Le fond du cadran : un disque sombre, pour que l'arc se detache d'un
	# decor clair comme d'un decor sombre.
	draw_circle(centre, rayon + 4.0, Color(0.043, 0.055, 0.086, 0.55))
	draw_arc(centre, rayon, depart, depart + arc, 32,
			Color(0.72, 0.70, 0.64, 0.40), 2.0)
	# Les graduations, tous les vingt kilometres/heure.
	var pas_grad := 20.0
	var g := 0.0
	while g <= maxi:
		var ang := depart + arc * (g / maxi)
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(centre + dir * (rayon - 4.0), centre + dir * rayon,
				Color(0.72, 0.70, 0.64, 0.45), 1.0)
		g += pas_grad
	# L'arc parcouru, ambre puis rouge dans le dernier quart — c'est la ou la
	# voiture cesse de tourner.
	var teinte := BB_AMBRE if part < 0.75 else BB_ROUGE
	if part > 0.01:
		draw_arc(centre, rayon, depart, depart + arc * part, 28, teinte, 3.0)
	# L'aiguille.
	var a := depart + arc * part
	var d := Vector2(cos(a), sin(a))
	draw_line(centre + d * 6.0, centre + d * (rayon - 2.0), teinte, 2.0)

	_ecrire(police, "%d" % roundi(_kmh), centre + Vector2(0.0, 6.0), 18,
			Color(0.949, 0.925, 0.867), false, HORIZONTAL_ALIGNMENT_CENTER)
	_ecrire(police, "km/h", centre + Vector2(0.0, 17.0), 9,
			Color(0.72, 0.70, 0.64), false, HORIZONTAL_ALIGNMENT_CENTER)


# Contour noir puis texte : sans lui, un chiffre clair passe devant un phare
# ou une facade claire et devient illisible une seconde sur trois.
func _ecrire(police: Font, texte: String, ou: Vector2, taille: int,
		couleur: Color, centre: bool,
		alignement: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT,
			-1, taille).x
	var p := ou
	if centre:
		p.x -= largeur / 2.0
	elif alignement == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= largeur

	var ombre := Color(0.043, 0.055, 0.086, couleur.a)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		police.draw_string(get_canvas_item(), p + d, texte,
				HORIZONTAL_ALIGNMENT_LEFT, -1, taille, ombre)
	police.draw_string(get_canvas_item(), p, texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
