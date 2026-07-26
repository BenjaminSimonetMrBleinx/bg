# La marche procedurale et les poses, detachees de qui les porte.
#
# Elles etaient dans joueur.gd, et n'y avaient rien a faire de particulier : le
# maillage est le meme pour tous les personnages, seules les textures changent.
# Un pieton de rue merite exactement la meme demarche que Walter, et la
# dupliquer aurait garanti qu'elles divergent au premier reglage.
#
# DEUX MECANISMES, ET ILS NE SE RESSEMBLENT PAS.
#
# La MARCHE est parametrique : sa phase avance avec la DISTANCE parcourue,
# jamais avec le temps. Les pieds ne patinent donc a aucune vitesse, et il n'y
# a aucun melange d'animations a doser. Aucune image cle ne la decrit, et c'est
# ce qui la rend juste partout.
#
# Les GESTES ne sont pas parametriques. Sortir un objet, tendre la main,
# s'accroupir : il n'y a pas de variable continue derriere, seulement un point
# d'arrivee. Ils vivent donc en donnees, dans donnees/poses.json, et se
# melangent par-dessus la marche segment par segment.
#
# Ce partage est le point important du fichier. Une premiere version aurait
# code chaque geste ici, comme la marche : au dixieme, plus personne n'aurait
# pu regler un bras sans ouvrir Godot, et chaque nouveau geste aurait coute
# dix lignes de sinus ecrits a la main.
#
# Un segment ABSENT d'une pose continue de marcher. C'est ce qui donne
# gratuitement « degainer en marchant » : la pose ne decrit que le bras.
#
# Tout ce qui decide de l'allure vit dans reglages.tres. Ce fichier ne contient
# pas un seul nombre de sensation.
class_name Silhouette
extends RefCounted

## Emis a chaque contact d'un pied avec le sol.
##
## La silhouette ne joue AUCUN son : elle ne sait pas sur quoi elle marche, ni
## si elle est celle du joueur ou d'un passant a trente metres. Elle dit
## seulement quand le pied touche, et laisse decider qui l'ecoute.
signal pas()

const SEGMENTS := ["Bassin", "Torse", "CuisseG", "CuisseD", "TibiaG",
		"TibiaD", "BrasG", "BrasD", "AvantBrasG", "AvantBrasD"]

const FICHIER := "res://donnees/poses.json"

## Les poses sont lues UNE FOIS pour tout le jeu, pas une fois par personnage.
## A quinze passants plus le joueur, relire et analyser le meme JSON seize fois
## au lancement est du travail rendu seize fois.
static var _catalogue: Dictionary = {}
static var _lu: bool = false

var _reglages: Reglages
var _membres: Dictionary = {}
var _repos: Dictionary = {}          # rotation d'origine de chaque segment
var _bassin_y: float = 0.0
var _phase: float = 0.0

## Distance parcourue depuis le dernier pied pose.
##
## On compte la DISTANCE et pas la phase : la phase tourne a l'envers quand on
## marche a reculons, et detecter un franchissement de seuil dans les deux sens
## avec le bouclage de 2 pi demande trois cas particuliers. La distance, elle,
## augmente toujours.
var _depuis_le_pas: float = 0.0

## La pose en cours, son poids actuel et le poids vise. Le poids monte vers 1
## quand on prend la pose, redescend vers 0 quand on la lache — et la pose
## n'est oubliee qu'une fois arrivee a zero, sinon le fondu de sortie sauterait.
var _pose: String = ""
var _poids: float = 0.0
var _vise: float = 0.0


func _init(reglages: Reglages) -> void:
	_reglages = reglages
	_charger()


static func _charger() -> void:
	if _lu:
		return
	_lu = true
	if not FileAccess.file_exists(FICHIER):
		push_error("silhouette : %s introuvable" % FICHIER)
		return
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(brut) != TYPE_DICTIONARY:
		push_error("silhouette : %s illisible. Verifier les virgules." % FICHIER)
		return
	_catalogue = (brut as Dictionary).get("poses", {})
	print("SILHOUETTE : %d pose(s) chargees" % _catalogue.size())


## Les poses connues. Un nom demande qui n'y est pas ne fait rien et le dit :
## c'est presque toujours une faute de frappe, et sans ce controle le geste
## manque simplement a l'ecran, sans erreur.
static func poses() -> Array:
	_charger()
	return _catalogue.keys()


## Retrouve les segments sous ce noeud. Par nom plutot que par chemin : la
## structure exacte d'un .glb importe varie d'une version de Godot a l'autre,
## mais les noms viennent de notre generateur et sont stables.
func recenser(racine: Node) -> int:
	_membres.clear()
	_repos.clear()
	for nom in SEGMENTS:
		var n := racine.find_child(nom, true, false)
		if n is Node3D:
			_membres[nom] = n
			# La rotation d'origine est relevee ICI, pas supposee nulle : le
			# modele sculpte a des segments legerement inclines dans son
			# maillage, et repartir de zero le redresserait de travers.
			_repos[nom] = (n as Node3D).rotation
	if _membres.has("Bassin"):
		_bassin_y = (_membres["Bassin"] as Node3D).position.y
	if _membres.size() < SEGMENTS.size():
		push_warning("silhouette : %d segments sur %d trouves sous %s"
				% [_membres.size(), SEGMENTS.size(), racine.name])
	return _membres.size()


# ------------------------------------------------------------------ les gestes

## Prend une pose. Elle se melange par-dessus la marche, segment par segment.
##
## Redemander la pose en cours ne relance pas le fondu : sans ce garde, une
## pose demandee a chaque image resterait bloquee a poids zero et le geste ne
## se verrait jamais.
func poser(nom: String) -> void:
	if nom == _pose and _vise > 0.0:
		return
	if not _catalogue.has(nom):
		push_warning("silhouette : aucune pose nommee '%s'. Les poses vivent "
				% nom + "dans %s" % FICHIER)
		return
	_pose = nom
	_vise = 1.0


## Lache la pose en cours et revient a la marche, en fondu.
func relacher() -> void:
	_vise = 0.0


## La pose en cours, ou une chaine vide. Sert aux tests et au debogage : le
## poids d'un fondu n'est visible nulle part ailleurs.
func pose() -> String:
	return _pose if _poids > 0.001 else ""


func poids() -> float:
	return _poids


# ---------------------------------------------------------------- chaque image

## A appeler chaque image de physique, avec la vitesse au sol en m/s.
##
## La vitesse peut etre NEGATIVE : le cycle tourne alors a l'envers, et le
## personnage marche vraiment a reculons. Avec une vitesse absolue il
## avancerait des jambes en se deplacant en arriere, ce qui se voit tout de
## suite.
func avancer(vitesse_au_sol: float, delta: float) -> void:
	_fondre(delta)

	if absf(vitesse_au_sol) < 0.15:
		# Retour a la position de repos, sans a-coup.
		_phase = lerp_angle(_phase, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		_appliquer(0.0)
		# A l'arret on repart presque pret a poser un pied : sans ca, le premier
		# pas apres un arret est muet, et c'est celui qu'on remarque.
		_depuis_le_pas = maxf(_depuis_le_pas, _reglages.foulee * 0.35)
		return

	_phase = fposmod(_phase + (vitesse_au_sol * delta)
			/ maxf(0.05, _reglages.foulee) * TAU, TAU)
	_appliquer(1.0)

	# Deux pieds par foulee, donc un contact toutes les demi-foulees.
	var demi := maxf(0.05, _reglages.foulee) * 0.5
	_depuis_le_pas += absf(vitesse_au_sol) * delta
	if _depuis_le_pas >= demi:
		# On retranche au lieu de remettre a zero : a grande vitesse une image
		# peut couvrir plus d'une demi-foulee, et remettre a zero perdrait le
		# reste, ce qui ferait deriver la cadence par rapport aux jambes.
		_depuis_le_pas = fmod(_depuis_le_pas, demi)
		pas.emit()


func _fondre(delta: float) -> void:
	if _pose == "":
		return
	var fiche: Dictionary = _catalogue[_pose]
	var duree := maxf(0.02, float(fiche.get("duree", 0.25)))
	_poids = move_toward(_poids, _vise, delta / duree)
	if _poids <= 0.0 and _vise <= 0.0:
		_pose = ""


# La marche calcule ses angles, la pose ecrase ceux qu'elle nomme, et le
# resultat est pose sur les segments. En un seul endroit : deux ecritures
# successives sur la meme rotation donneraient un tremblement d'une image sur
# deux, ce qui se voit et ne s'explique pas.
func _appliquer(intensite: float) -> void:
	var angles := _marche(intensite)
	var bassin := _bassin_y + absf(sin(_phase)) * _reglages.rebond * intensite

	if _poids > 0.001 and _catalogue.has(_pose):
		var fiche: Dictionary = _catalogue[_pose]
		for nom in fiche.get("segments", {}):
			var v: Array = fiche["segments"][nom]
			if v.size() < 3:
				continue
			var cible := Vector3(deg_to_rad(float(v[0])),
					deg_to_rad(float(v[1])), deg_to_rad(float(v[2])))
			# Le segment absent de la marche part de son repos, pas de zero.
			var depart: Vector3 = angles.get(nom, _repos.get(nom, Vector3.ZERO))
			angles[nom] = depart.lerp(cible, _poids)
		bassin += float(fiche.get("bassin", 0.0)) * _poids

	for nom in angles:
		if _membres.has(nom):
			(_membres[nom] as Node3D).rotation = angles[nom]
	if _membres.has("Bassin"):
		(_membres["Bassin"] as Node3D).position.y = bassin


# Le cycle de marche, en angles plutot qu'en ecritures directes. C'est ce
# decoupage qui permet a une pose de s'y superposer : tant que la marche
# ecrivait elle-meme sur les segments, il n'y avait aucun endroit ou intervenir.
func _marche(intensite: float) -> Dictionary:
	var jambe := deg_to_rad(_reglages.amplitude_jambe) * intensite
	var genou := deg_to_rad(_reglages.amplitude_genou) * intensite
	var bras := deg_to_rad(_reglages.amplitude_bras) * intensite
	var coude := deg_to_rad(_reglages.amplitude_coude) * intensite

	var s := sin(_phase)
	var so := sin(_phase + PI)

	var a := {}
	a["CuisseG"] = _x("CuisseG", s * jambe)
	a["CuisseD"] = _x("CuisseD", so * jambe)
	# Le genou ne plie que vers l'arriere : on ne garde que la moitie negative
	# du cycle. Un genou qui plie a l'envers est le defaut le plus visible d'une
	# marche procedurale ratee.
	a["TibiaG"] = _x("TibiaG", -maxf(0.0, sin(_phase - 0.7)) * genou)
	a["TibiaD"] = _x("TibiaD", -maxf(0.0, sin(_phase + PI - 0.7)) * genou)

	a["BrasG"] = _x("BrasG", so * bras)
	a["BrasD"] = _x("BrasD", s * bras)
	a["AvantBrasG"] = _x("AvantBrasG", -(0.5 + 0.5 * sin(_phase + PI)) * coude)
	a["AvantBrasD"] = _x("AvantBrasD", -(0.5 + 0.5 * sin(_phase)) * coude)

	# Un leger roulis du torse enleve l'impression de pantin.
	var t: Vector3 = _repos.get("Torse", Vector3.ZERO)
	a["Torse"] = Vector3(t.x, t.y,
			t.z + s * deg_to_rad(_reglages.roulis_torse) * intensite)
	return a


func _x(nom: String, angle: float) -> Vector3:
	var r: Vector3 = _repos.get(nom, Vector3.ZERO)
	return Vector3(r.x + angle, r.y, r.z)
