# La minimap, en bas a droite, et la direction de l'objectif.
#
# CE QU'ELLE REPARE. L'objectif ne se lisait que dans le telephone, en texte :
# « Rejoindre le labo dans le desert ». La ville fait 519 m de cote, elle a
# quatre-vingt-un carrefours, et le desert est a neuf cents metres. Rien ne
# disait de quel cote tourner.
#
# AUCUN CHIFFRE, et ce n'est pas une coquetterie : la regle 1 du projet ne
# souffre que trois exceptions — l'argent, la famille, la reputation — et une
# distance n'en est pas une. On montre une direction et une forme. Savoir qu'il
# reste « 340 m » transforme un trajet en optimisation ; voir que le point est
# loin sur la gauche laisse conduire.
#
# LE PLAN NE SE FABRIQUE PAS, IL SE LIT DES LAMPADAIRES. Ils bordent les rues —
# c'est leur raison d'etre — donc les semer sur le disque dessine le reseau
# sans qu'on ait a produire, stocker et resynchroniser une carte. Cinq cent
# vingt-six points, filtres par distance : il en reste une quarantaine a
# l'ecran.
#
# ELLE TOURNE AVEC LA CAMERA. Un plan oriente au nord oblige a faire la
# rotation dans sa tete pendant qu'on conduit. Le haut du disque est ce qu'on a
# devant soi, comme dans tous les jeux qui en ont une.
extends Control

@export var reglages: Reglages
@export var joueur: NodePath
@export var mission: NodePath

## Le trace des rues, en coordonnees monde. Lu une fois : les lampadaires ne
## bougent pas, et relire un fichier de cinq cents entrees a chaque image
## couterait plus que tout le reste du HUD.
var _rues: PackedVector2Array = PackedVector2Array()

var _joueur: Node3D
var _mission: Mission
var _cible: Node3D
var _cible_nom: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joueur = get_node_or_null(joueur) as Node3D
	_mission = get_node_or_null(mission) as Mission
	_lire_les_rues()
	set_process(true)


func _process(_delta: float) -> void:
	# On redessine a chaque image : la position et le cap changent en continu,
	# et un disque de cette taille ne coute rien.
	queue_redraw()


# Les lampadaires viennent du meme fichier que la ville, et on ne garde que
# leur position au sol : la hauteur ne sert a rien sur un plan.
func _lire_les_rues() -> void:
	const FICHIER := "res://assets/ville/ville_lampes.json"
	if not FileAccess.file_exists(FICHIER):
		return
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(brut) != TYPE_DICTIONARY:
		return
	for e in (brut as Dictionary).get("lampes", []):
		var p: Array = e["pos"]
		_rues.append(Vector2(float(p[0]), float(p[2])))


# LE NOEUD CIBLE EST CHERCHE UNE FOIS PAR ETAPE, pas a chaque image.
#
# find_child descend tout l'arbre — plus de onze mille noeuds. A soixante
# images par seconde ce serait le poste le plus cher du jeu, pour une reponse
# qui ne change qu'aux quinze changements d'etape de la mission.
func _cible_courante() -> Node3D:
	if _mission == null:
		return null
	var nom := _mission.ou()
	if nom == _cible_nom and is_instance_valid(_cible):
		return _cible
	_cible_nom = nom
	_cible = null
	if nom != "":
		# ON PART DU PARENT DE LA MISSION, PAS DE current_scene.
		#
		# current_scene est la scene chargee par le moteur : pendant une
		# transition elle peut etre nulle, ou etre encore l'ecran-titre. La
		# mission, elle, est toujours posee sous le noeud Monde — c'est le bon
		# repere, et il n'a pas d'etat transitoire.
		var racine := _mission.get_parent()
		if racine != null:
			_cible = racine.find_child(nom, true, false) as Node3D
		# ON LE DIT QUAND ON NE TROUVE PAS.
		#
		# Sans ca, une cible mal nommee dans mission1.json donne exactement le
		# meme resultat qu'une etape sans cible : pas de marqueur, et rien pour
		# distinguer « il n'y a rien a montrer » de « je cherche un noeud qui
		# n'existe pas ». C'est arrive au premier essai.
		if _cible == null:
			push_warning("minimap : etape '%s' vise '%s', introuvable dans la scene"
					% [_mission.cle_etape(), nom])
	return _cible


## Ce qui, ouvert, doit faire disparaitre la minimap.
##
## Ils occupent le meme coin ou passent devant. Le telephone se pose pile
## dessus : sur la premiere capture, il en recouvrait les trois quarts et il ne
## restait qu'un croissant de disque a depasser — le genre de detail qu'on ne
## remarque qu'en jouant, et qui fait sale.
##
## On regarde des FRERES par leur nom plutot que de se faire injecter trois
## NodePath : ils vivent tous sous le meme Control d'echelle, et un nom absent
## est simplement ignore.
const CE_QUI_PASSE_DEVANT := ["Telephone", "Roue", "Pause", "FinDePartie",
		"CadreDialogue", "Cachette"]


func _draw() -> void:
	if reglages == null or not reglages.minimap or _joueur == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var parent := get_parent()
	if parent != null:
		for nom in CE_QUI_PASSE_DEVANT:
			var n := parent.get_node_or_null(NodePath(nom))
			if n is CanvasItem and (n as CanvasItem).visible:
				return

	var r := reglages.minimap_rayon
	var c := Vector2(size.x - r - reglages.minimap_marge,
			size.y - r - reglages.minimap_marge)

	# Le cap de la CAMERA, pas celui du joueur : c'est ce qu'on a sous les yeux.
	# En voiture on regarde souvent ailleurs que devant, et la carte doit suivre
	# le regard.
	var cap := cam.global_transform.basis.z
	var angle := atan2(cap.x, cap.z)
	var ici := Vector2(_joueur.global_position.x, _joueur.global_position.z)

	draw_circle(c, r, reglages.minimap_fond)

	# Les rues. On coupe au carre d'abord — comparer deux carres evite cinq
	# cents racines carrees par image, et le disque les recadre ensuite.
	var portee := reglages.minimap_portee
	var portee2 := portee * portee
	var echelle := r / portee
	for p in _rues:
		var d := p - ici
		if d.length_squared() > portee2:
			continue
		var v := d.rotated(angle) * echelle
		if v.length() > r - 1.0:
			continue
		draw_rect(Rect2(c + v - Vector2(0.5, 0.5), Vector2(1.5, 1.5)),
				reglages.minimap_rue)

	_dessiner_objectif(c, r, ici, angle, echelle)

	# LE JOUEUR EST UN TRIANGLE, pas un point : il faut qu'il porte le sens.
	# Il est toujours au centre et toujours pointe vers le haut, puisque c'est
	# la carte qui tourne.
	var t := PackedVector2Array([
		c + Vector2(0.0, -4.5), c + Vector2(-3.0, 3.5), c + Vector2(3.0, 3.5)])
	draw_colored_polygon(t, reglages.minimap_joueur)

	# Le bord en dernier : il recouvre les points qui frolent la limite.
	draw_arc(c, r, 0.0, TAU, 40, reglages.minimap_bord, 1.0, false)


# L'OBJECTIF RESTE VISIBLE MEME LOIN, colle au bord du disque.
#
# C'est tout l'interet : le desert est a neuf cents metres, donc trente fois
# hors du disque. Un marqueur qui disparait des qu'on sort de portee ne sert
# qu'a l'endroit ou on n'en a plus besoin.
func _dessiner_objectif(c: Vector2, r: float, ici: Vector2, angle: float,
		echelle: float) -> void:
	var cible := _cible_courante()
	if cible == null:
		return
	var d := Vector2(cible.global_position.x, cible.global_position.z) - ici
	var v := d.rotated(angle) * echelle
	var au_bord := v.length() > r - 4.0
	if au_bord:
		v = v.normalized() * (r - 4.0)
	var p := c + v
	if au_bord:
		# Une pointe tournee vers l'exterieur : elle dit « par la, et c'est
		# plus loin que ce disque ».
		var a := v.angle()
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(4.5, 0).rotated(a),
			p + Vector2(-2.5, 3.5).rotated(a),
			p + Vector2(-2.5, -3.5).rotated(a)]), reglages.minimap_objectif)
	else:
		draw_circle(p, 3.0, reglages.minimap_objectif)
