# Ce que Walter tient en main, ou porte sur la tete.
#
# Les objets sont charges une fois pour toutes au demarrage et accroches a
# leur segment de corps, puis simplement masques. Les instancier a chaque
# changement provoquerait un temps de chargement au moment precis ou l'on
# tourne la roue — c'est-a-dire au pire moment.
#
# Rien de ce fichier ne connait un objet en particulier : tout vient de
# donnees/outils.json, y compris la liste et l'ordre des parts de la roue.
class_name Equipement
extends Node

const FICHIER := "res://donnees/outils.json"
const DOSSIER := "res://assets/objets/%s.glb"

## Aucun objet en main. Vaut mieux qu'un index nul : « les mains vides » est
## un etat legitime, pas une absence de donnee.
const RIEN := -1

signal change(index: int)

## Emis quand on demande a mettre ou a enlever un objet qui SE PORTE.
##
## Le port ne bascule pas tout de suite : il bascule au milieu du geste, quand
## la main est au crane. Ce signal est ce qui permet au controleur de lancer
## l'animation sans que ce fichier sache qu'un joueur existe.
signal port_demande(cle: String, mettre: bool)

## Combien de temps la main met a arriver sur la tete, en secondes.
##
## C'est le milieu du clip « Coiffer », pas un nombre choisi : le chapeau doit
## apparaitre quand la main y est. Trop tot, il se materialise sous la main ;
## trop tard, la main redescend et le chapeau arrive tout seul.
const DELAI_DU_PORT := 0.45

## Le personnage qui porte les objets. Ses segments sont retrouves par nom.
@export var porteur: NodePath

var _fiches: Array = []
var _noeuds: Array[Node3D] = []
var _actif: int = RIEN
var _porteur: Node3D
var _audio: Audio

## CE QU'ON POSSEDE, dans l'ordre de la roue. Ce sont des indices de fiches.
##
## outils.json decrit tout ce qui EXISTE dans le jeu ; ceci dit ce que Walter a
## sur lui a cet instant. Les deux etaient confondus jusqu'ici — la roue
## montrait le catalogue — ce qui donnait un chimiste demarrant la partie avec
## un revolver et un sachet de meth, et une mission entiere consacree a aller
## chercher les deux.
##
## Vide au chargement veut dire « tout », pour que le bac a sable continue de
## marcher sans mission.
var _possedes: Array[int] = []

## UNE MISSION A-T-ELLE POSE L'INVENTAIRE ?
##
## Sans ce drapeau, « je n'ai rien » et « personne ne m'a rien dit » etaient le
## meme etat : la liste vide. Tant que la mission commencait avec deux objets
## la confusion ne se voyait pas, mais le jour ou elle demarre les mains vides —
## ce qui est desormais le cas — Walter recevait le CATALOGUE ENTIER, revolver
## et marchandise compris, c'est-a-dire exactement ce que la mission consiste a
## aller chercher.
##
## Le bac a sable, lui, ne pose rien du tout et garde ses jouets.
var _impose: bool = false

## LES OBJETS QU'ON PORTE, par indice de fiche.
##
## Un chapeau n'est pas un objet qu'on tient : on le met, et il reste sur la
## tete pendant qu'on tient autre chose. Le confondre avec le reste de la roue
## donnait un Walter qui devait choisir entre son revolver et son chapeau, et
## qui perdait le second en degainant.
var _portes: Dictionary = {}

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


func _ready() -> void:
	_porteur = get_node_or_null(porteur) as Node3D
	if _porteur == null:
		push_error("equipement : porteur introuvable (%s)" % porteur)
		return
	_charger()
	_accrocher()


func _charger() -> void:
	if not FileAccess.file_exists(FICHIER):
		push_error("equipement : %s introuvable" % FICHIER)
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(lu) != TYPE_DICTIONARY:
		push_error("equipement : %s illisible. Verifier les virgules." % FICHIER)
		return
	_fiches = (lu as Dictionary).get("outils", [])


func _accrocher() -> void:
	for fiche in _fiches:
		var cle := str(fiche.get("cle", ""))
		var chemin := DOSSIER % cle
		if not ResourceLoader.exists(chemin):
			push_error("equipement : %s introuvable. Regenerer : " % chemin
					+ "blender -b -P outils/gen_objets.py -- --nom tous")
			_noeuds.append(null)
			continue

		var ancre := _segment(str(fiche.get("ancrage", "MainD")))
		if ancre == null:
			_noeuds.append(null)
			continue

		var n := (ResourceLoader.load(chemin) as PackedScene).instantiate() as Node3D
		var k := _noeuds.size()
		_ancres[k] = ancre
		_decalages[k] = _vecteur(fiche.get("position", [0, 0, 0]))
		_aplombs[k] = _vecteur(fiche.get("aplomb", [0, 0, 0]))
		_echelles[k] = float(fiche.get("echelle", 1.0))
		var r := _vecteur(fiche.get("rotation", [0, 0, 0]))
		n.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
		n.visible = false
		ancre.add_child(n)
		_noeuds.append(n)

	var manquants := _noeuds.count(null)
	print("EQUIPEMENT : %d objet(s) accroches sur %d" %
			[_noeuds.size() - manquants, _fiches.size()])


## Ou accrocher, quand le personnage a un SQUELETTE au lieu de segments.
##
## Les deux corps coexistent : Walter est rigge, les passants sont encore des
## hierarchies de segments nommes. Plutot que d'imposer un vocabulaire au rig
## livre — ce qui obligerait Guillaume a renommer ses os a chaque fois — on
## traduit ici. Les noms de droite sont ceux de tout rig humanoide.
const OS_DU_RIG := {
	"MainD": "RightHand",
	"MainG": "LeftHand",
	"Tete": "Head",
	"Torse": "Spine02",
	"Bassin": "Hips",
}


# Sur un squelette, un objet ne s'accroche pas a un noeud : il faut un
# BoneAttachment3D, qui suit l'os image par image. Un Node3D pose a cote ne
# bougerait pas d'un pouce pendant que le bras, lui, bouge.
func _segment(nom: String) -> Node3D:
	var squelette := _porteur.find_child("Skeleton3D", true, false) as Skeleton3D
	if squelette != null:
		var os := str(OS_DU_RIG.get(nom, nom))
		if squelette.find_bone(os) < 0:
			push_error("equipement : os '%s' absent du squelette (pour '%s'). "
					% [os, nom] + "Os disponibles : %s"
					% ", ".join(_noms_des_os(squelette)))
			return null
		# Un attache par os, reutilise : quatre objets sur la meme main ne
		# demandent pas quatre attaches.
		var existant := squelette.get_node_or_null(NodePath("Attache_" + os))
		if existant != null:
			return existant as Node3D
		var attache := BoneAttachment3D.new()
		attache.name = "Attache_" + os
		attache.bone_name = os
		squelette.add_child(attache)
		return attache

	var n := _porteur.find_child(nom, true, false)
	if n is Node3D:
		return n as Node3D
	push_error("equipement : ni squelette, ni segment '%s' sur le personnage" % nom)
	return null


static func _noms_des_os(s: Skeleton3D) -> Array:
	var noms := []
	for i in s.get_bone_count():
		noms.append(s.get_bone_name(i))
	return noms


static func _vecteur(v: Variant) -> Vector3:
	var a: Array = v if typeof(v) == TYPE_ARRAY else [0, 0, 0]
	if a.size() < 3:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


# -------------------------------------------------------------- l'inventaire
#
# Tout ce qui suit parle en indices de ROUE, pas en indices de fiches. La roue
# affiche ce qu'on possede et rien d'autre ; la conversion se fait ici, et
# nulle part ailleurs.


func _fiche_de(rang: int) -> int:
	if not _impose:
		return rang
	if rang < 0 or rang >= _possedes.size():
		return RIEN
	return _possedes[rang]


func _rang_de(fiche: int) -> int:
	if not _impose:
		return fiche
	return _possedes.find(fiche)


func _indice_de_cle(cle: String) -> int:
	for i in _fiches.size():
		if str(_fiches[i].get("cle", "")) == cle:
			return i
	return RIEN


## Fixe l'inventaire de depart. Une liste vide rend TOUT disponible, ce qui est
## le comportement du bac a sable : sans mission chargee, on veut ses jouets.
func definir_inventaire(cles: Array) -> void:
	_possedes.clear()
	_portes.clear()
	_impose = true
	for c in cles:
		var i := _indice_de_cle(str(c))
		if i == RIEN:
			push_warning("equipement : '%s' n'est pas dans outils.json" % c)
			continue
		_possedes.append(i)
	equiper(RIEN)


## Teinte un objet tenu. Le multiplicateur s'applique a la couleur de base du
## materiau : la matiere et le grain restent, seule la teinte se deplace.
##
## ON REPART TOUJOURS DU MATERIAU DU MAILLAGE, jamais de la surcharge posee au
## passage precedent : relire la surcharge multiplierait la teinte par
## elle-meme, et le cristal virerait au noir en trois changements de palier.
func teinter(cle: String, teinte: Color) -> void:
	var i := _indice_de_cle(cle)
	if i == RIEN or i >= _noeuds.size() or _noeuds[i] == null:
		return
	_teinter(_noeuds[i], teinte)


func _teinter(n: Node, teinte: Color) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			var origine := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if origine == null:
				continue
			var copie := origine.duplicate() as StandardMaterial3D
			copie.albedo_color = teinte
			mi.set_surface_override_material(s, copie)
	for e in n.get_children():
		_teinter(e, teinte)


## TOUTES les cles de outils.json, possedees ou non. Sert aux outils de test :
## « donner tout » ne doit pas tenir une seconde liste qui se perimerait des
## qu'on ajoute un objet au fichier.
func toutes_les_cles() -> Array:
	var sortie: Array = []
	for f in _fiches:
		sortie.append(str(f.get("cle", "")))
	return sortie


## Les cles de ce qu'on possede, dans l'ordre de la roue. Pour la sauvegarde.
func cles_possedees() -> Array:
	var sortie: Array = []
	for i in _possedes:
		sortie.append(str(_fiches[i].get("cle", "")))
	return sortie


## Les cles de ce qu'on PORTE en ce moment (le chapeau), par opposition a ce
## qu'on tient en main. Pour la sauvegarde : les deux se restaurent autrement.
func cles_portees() -> Array:
	var sortie: Array = []
	for i in _portes.keys():
		if bool(_portes[i]):
			sortie.append(str(_fiches[i].get("cle", "")))
	return sortie


## Restaure l'inventaire d'une sauvegarde : ce qu'on possede, ce qu'on porte,
## ce qu'on tient. On rejoue le port et la mise en main par equiper(), pour que
## le visuel suive exactement comme si le joueur l'avait fait lui-meme.
func restaurer(possedes: Array, tenu: String, portes: Array) -> void:
	definir_inventaire(possedes)
	# Le port se pose DIRECTEMENT, sans le delai ni l'animation de
	# _demander_le_port : recharger une partie n'est pas remettre son chapeau
	# geste par geste, c'est le retrouver deja dessus.
	for c in portes:
		var ip := _indice_de_cle(str(c))
		if ip != RIEN:
			_portes[ip] = true
	# Ce qu'on tient en main, lui, se pose par la voie normale : elle est
	# instantanee, et gere le visuel comme l'etat.
	if tenu != "":
		var it := _indice_de_cle(tenu)
		if it != RIEN:
			equiper(_rang_de(it))
	_montrer()


func possede(cle: String) -> bool:
	var i := _indice_de_cle(cle)
	return i != RIEN and (not _impose or _possedes.has(i))


## Ramasser quelque chose. Renvoie faux si on l'avait deja — l'appelant s'en
## sert pour ne pas rejouer l'annonce.
func donner(cle: String) -> bool:
	var i := _indice_de_cle(cle)
	if i == RIEN or _possedes.has(i):
		return false
	_possedes.append(i)
	# On garde l'ordre de outils.json : la roue doit avoir la meme disposition
	# d'une partie a l'autre, sinon on cherche son objet a chaque fois.
	_possedes.sort()
	return true


func retirer(cle: String) -> bool:
	var i := _indice_de_cle(cle)
	if i == RIEN or not _possedes.has(i):
		return false
	if _actif == i:
		equiper(RIEN)
	_portes.erase(i)
	_montrer()
	_possedes.erase(i)
	return true


func nombre() -> int:
	return _possedes.size() if _impose else _fiches.size()


## Le nom affichable d'un objet, DEPUIS SA CLE.
##
## nom_de() prend un rang dans la roue, et le rang d'un objet qu'on vient de
## ramasser n'est pas le dernier : _possedes est trie sur l'ordre de
## outils.json, pour que la roue garde la meme disposition d'une partie a
## l'autre. Le scenario annoncait donc « nombre() - 1 » a chaque ramassage, et
## comme le chapeau est le dernier de la liste, tout ce qu'on ramassait
## s'annoncait « Porkpie » — y compris le revolver de la boite a gants.
func nom_pour_cle(cle: String) -> String:
	var i := _indice_de_cle(cle)
	if i == RIEN:
		return cle.capitalize()
	return str(_fiches[i].get("nom", cle))


func nom_de(rang: int) -> String:
	var i := _fiche_de(rang)
	if i < 0 or i >= _fiches.size():
		return "Rien"
	return str(_fiches[i].get("nom", _fiches[i].get("cle", "?")))


## La cle de l'objet en main, ou "" les mains vides. C'est par elle que le tir
## sait qu'on tient le revolver, sans avoir a connaitre son rang dans la roue.
func cle_equipee() -> String:
	if _actif < 0 or _actif >= _fiches.size():
		return ""
	return str(_fiches[_actif].get("cle", ""))


func actif() -> int:
	return _rang_de(_actif) if _actif != RIEN else RIEN


## Cet objet se PORTE-t-il, au lieu de se tenir ? Vient de outils.json : le
## code ne connait aucun chapeau en particulier.
func _se_porte(i: int) -> bool:
	return i >= 0 and i < _fiches.size() and bool(_fiches[i].get("porte", false))


## Lu par les tests : cette fiche decrit-elle un objet qui se porte ? La
## question se pose sur un RANG de roue, comme tout le reste de l'interface.
func est_porte_par_nature(rang: int) -> bool:
	return _se_porte(_fiche_de(rang))


## Le porte-t-on en ce moment ?
func porte(cle: String) -> bool:
	var i := _indice_de_cle(cle)
	return i != RIEN and bool(_portes.get(i, false))


## Equipe l'objet d'indice i, ou RIEN pour ranger. Reequiper celui qu'on a
## deja en main le range : c'est le comportement attendu d'une roue, et ca
## evite d'avoir une part « rien » qui n'aurait servi qu'a ca.
##
## Un objet qui se PORTE ne suit pas cette regle : il ne va pas en main, il se
## met ou s'enleve, et il ne touche pas a ce qu'on tenait.
func equiper(rang: int) -> void:
	var i := _fiche_de(rang) if rang != RIEN else RIEN
	if i != RIEN and _se_porte(i):
		_demander_le_port(i)
		return
	if i == _actif:
		i = RIEN
	_actif = i
	_montrer()
	_sonner(i)
	change.emit(actif())


## Equipe ou porte un objet DESIGNE PAR SA CLE.
##
## Le rang dans la roue depend de ce qu'on possede a cet instant ; la cle, non.
## C'est ce qui permet a un scenario de capture ou a une mission de demander un
## objet precis sans compter les parts.
func equiper_cle(cle: String) -> void:
	var i := _indice_de_cle(cle)
	if i == RIEN:
		push_warning("equipement : '%s' n'est pas dans outils.json" % cle)
		return
	var rang := _rang_de(i)
	if rang == RIEN:
		# Sans ce refus explicite, equiper(RIEN) rangeait tout et l'on croyait
		# a un objet qui ne s'affiche pas, alors qu'on ne le possede pas.
		push_warning("equipement : '%s' n'est pas dans l'inventaire" % cle)
		return
	equiper(rang)


## L'ECHELLE DE L'OS, et le bug qu'elle a cache pendant tout ce temps.
##
## Une attache d'os herite de l'echelle du squelette. Sur ce rig elle vaut
## 0,011 — les os y sont longs de deux mille unites — et tout ce qu'on accroche
## dessus est donc rendu a un centieme de sa taille. Le revolver mesurait deux
## millimetres, le livre un millimetre et demi, le chapeau autant. Ils etaient
## charges, accroches, declares visibles, et invisibles a l'ecran : c'est le
## « objet equipe pas visible en main » du retour precedent, et c'est la meme
## cause que le chapeau qui ne se posait pas.
##
## Rien ne prevenait, parce que rien n'etait faux : le noeud etait bien la, au
## bon endroit, a la bonne echelle DANS SON REPERE.
##
## On rattrape donc les trois choses d'un coup, au premier affichage :
##
##   echelle    divisee par celle de l'ancrage, pour que 1.0 veuille dire « la
##              taille du modele »
##   position   un decalage en METRES, dans les axes de l'os, donc il suit
##              l'os quand il tourne
##   aplomb     un decalage en METRES a la verticale du MONDE, fige une fois
##              pour toutes. C'est ce qu'il faut pour poser quelque chose SUR
##              quelqu'un sans dependre de l'orientation de l'os
##
## Au premier affichage et pas a la construction : le calcul a besoin d'un
## squelette pose, ce qu'il n'est pas encore quand la scene se monte.
var _ancres: Dictionary = {}
var _decalages: Dictionary = {}
var _aplombs: Dictionary = {}
var _echelles: Dictionary = {}
var _cales: Dictionary = {}


func _caler(k: int) -> void:
	if _cales.has(k):
		return
	var ancre := _ancres.get(k) as Node3D
	if ancre == null or not ancre.is_inside_tree():
		return
	var base := ancre.global_transform.basis
	var facteur: float = maxf(1e-6, base.get_scale().y)
	_noeuds[k].scale = Vector3.ONE * (float(_echelles[k]) / facteur)
	_noeuds[k].position = (_decalages[k] as Vector3) / facteur \
			+ base.inverse() * (_aplombs[k] as Vector3)
	_cales[k] = true


## Etat complet, imprime. Appele depuis un scenario de capture ou une console :
## une image qui ne montre pas le chapeau ne dit pas s'il n'est pas porte, pas
## charge, ou pose a un metre du crane. Les trois se ressemblent, et cherchent
## dans trois directions differentes.
func journal() -> void:
	print("EQUIPEMENT : actif=%d  impose=%s" % [_actif, _impose])
	for k in _fiches.size():
		var n := _noeuds[k] if k < _noeuds.size() else null
		print("   %-9s possede=%s porte=%s noeud=%s visible=%s y=%s"
				% [str(_fiches[k].get("cle", "?")),
				   "oui" if (not _impose or _possedes.has(k)) else "non",
				   "oui" if bool(_portes.get(k, false)) else "non",
				   "oui" if n != null else "MANQUANT",
				   "oui" if (n != null and n.is_visible_in_tree()) else "non",
				   "%.2f" % n.global_position.y if n != null else "-"])


func _montrer() -> void:
	for k in _noeuds.size():
		if _noeuds[k] == null:
			continue
		var vu: bool = (k == _actif) or bool(_portes.get(k, false))
		if vu:
			_caler(k)
		_noeuds[k].visible = vu


# Le port bascule APRES le delai du geste, pas a l'instant du choix. Sans ce
# decalage, le chapeau apparaissait sur la tete pendant que la main partait le
# chercher — ce qui donne moins l'impression de se coiffer que d'assister a un
# tour de magie rate.
func _demander_le_port(i: int) -> void:
	var cle := str(_fiches[i].get("cle", ""))
	var mettre := not bool(_portes.get(i, false))
	port_demande.emit(cle, mettre)
	var minuteur := get_tree().create_timer(DELAI_DU_PORT)
	minuteur.timeout.connect(func() -> void:
		_portes[i] = mettre
		_montrer()
		_sonner(i)
		change.emit(actif()))


# Le nom du son se DEDUIT de la cle de l'objet : « livre » -> « objet_livre ».
# Ajouter un objet qui fait du bruit ne demande donc pas de toucher a ce
# fichier — une entree dans outils.json, une ligne dans sons.json, c'est tout.
#
# Un objet sans son declare est un cas parfaitement normal : l'arme n'en a
# pas. On verifie donc AVANT d'appeler, sinon chaque equipement d'arme
# imprimerait un avertissement pour un comportement voulu.
func _sonner(i: int) -> void:
	if _son() == null or i == RIEN or i >= _fiches.size():
		return
	var nom := "objet_%s" % str(_fiches[i].get("cle", ""))
	if _son().connait(nom):
		_son().bruit(nom)
