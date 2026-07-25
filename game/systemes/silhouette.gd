# La marche procedurale, detachee de qui marche.
#
# Elle etait dans joueur.gd, et n'y avait rien a faire de particulier : le
# maillage est le meme pour tous les personnages, seules les textures
# changent. Un pieton de rue merite exactement la meme demarche que Walter,
# et la dupliquer aurait garanti qu'elles divergent au premier reglage.
#
# Principe : la phase avance avec la DISTANCE parcourue, jamais avec le
# temps. Les pieds ne patinent donc a aucune vitesse, et il n'y a aucun
# melange d'animations a doser.
#
# Tout ce qui decide de l'allure vit dans reglages.tres. Ce fichier ne
# contient pas un seul nombre de sensation.
class_name Silhouette
extends RefCounted

## Emis a chaque contact d'un pied avec le sol.
##
## La silhouette ne joue AUCUN son : elle ne sait pas sur quoi elle marche,
## ni si elle est celle du joueur ou d'un passant a trente metres. Elle dit
## seulement quand le pied touche, et laisse decider qui l'ecoute.
signal pas()

const SEGMENTS := ["Bassin", "Torse", "CuisseG", "CuisseD", "TibiaG",
		"TibiaD", "BrasG", "BrasD", "AvantBrasG", "AvantBrasD"]

var _reglages: Reglages
var _membres: Dictionary = {}
var _bassin_y: float = 0.0
var _phase: float = 0.0

## Distance parcourue depuis le dernier pied pose.
##
## On compte la DISTANCE et pas la phase : la phase tourne a l'envers quand on
## marche a reculons, et detecter un franchissement de seuil dans les deux
## sens avec le bouclage de 2 pi demande trois cas particuliers. La distance,
## elle, augmente toujours.
var _depuis_le_pas: float = 0.0


func _init(reglages: Reglages) -> void:
	_reglages = reglages


## Retrouve les segments sous ce noeud. Par nom plutot que par chemin : la
## structure exacte d'un .glb importe varie d'une version de Godot a l'autre,
## mais les noms viennent de notre generateur et sont stables.
func recenser(racine: Node) -> int:
	_membres.clear()
	for nom in SEGMENTS:
		var n := racine.find_child(nom, true, false)
		if n is Node3D:
			_membres[nom] = n
	if _membres.has("Bassin"):
		_bassin_y = (_membres["Bassin"] as Node3D).position.y
	if _membres.size() < SEGMENTS.size():
		push_warning("silhouette : %d segments sur %d trouves sous %s"
				% [_membres.size(), SEGMENTS.size(), racine.name])
	return _membres.size()


## A appeler chaque image de physique, avec la vitesse au sol en m/s.
##
## La vitesse peut etre NEGATIVE : le cycle tourne alors a l'envers, et le
## personnage marche vraiment a reculons. Avec une vitesse absolue il
## avancerait des jambes en se deplacant en arriere, ce qui se voit tout de
## suite.
func avancer(vitesse_au_sol: float, delta: float) -> void:
	if absf(vitesse_au_sol) < 0.15:
		# Retour a la position de repos, sans a-coup.
		_phase = lerp_angle(_phase, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		_poser(0.0)
		# A l'arret on repart presque pret a poser un pied : sans ca, le
		# premier pas apres un arret est muet, et c'est celui qu'on remarque.
		_depuis_le_pas = maxf(_depuis_le_pas, _reglages.foulee * 0.35)
		return

	_phase = fposmod(_phase + (vitesse_au_sol * delta)
			/ maxf(0.05, _reglages.foulee) * TAU, TAU)
	_poser(1.0)

	# Deux pieds par foulee, donc un contact toutes les demi-foulees.
	var demi := maxf(0.05, _reglages.foulee) * 0.5
	_depuis_le_pas += absf(vitesse_au_sol) * delta
	if _depuis_le_pas >= demi:
		# On retranche au lieu de remettre a zero : a grande vitesse une image
		# peut couvrir plus d'une demi-foulee, et remettre a zero perdrait le
		# reste, ce qui ferait deriver la cadence par rapport aux jambes.
		_depuis_le_pas = fmod(_depuis_le_pas, demi)
		pas.emit()


func _poser(intensite: float) -> void:
	var jambe := deg_to_rad(_reglages.amplitude_jambe) * intensite
	var genou := deg_to_rad(_reglages.amplitude_genou) * intensite
	var bras := deg_to_rad(_reglages.amplitude_bras) * intensite
	var coude := deg_to_rad(_reglages.amplitude_coude) * intensite

	var s := sin(_phase)
	var so := sin(_phase + PI)

	_tourner("CuisseG", s * jambe)
	_tourner("CuisseD", so * jambe)
	# Le genou ne plie que vers l'arriere : on ne garde que la moitie negative
	# du cycle. Un genou qui plie a l'envers est le defaut le plus visible
	# d'une marche procedurale ratee.
	_tourner("TibiaG", -maxf(0.0, sin(_phase - 0.7)) * genou)
	_tourner("TibiaD", -maxf(0.0, sin(_phase + PI - 0.7)) * genou)

	_tourner("BrasG", so * bras)
	_tourner("BrasD", s * bras)
	_tourner("AvantBrasG", -(0.5 + 0.5 * sin(_phase + PI)) * coude)
	_tourner("AvantBrasD", -(0.5 + 0.5 * sin(_phase)) * coude)

	# Le bassin monte deux fois par foulee, une fois par appui.
	if _membres.has("Bassin"):
		var b: Node3D = _membres["Bassin"]
		b.position.y = _bassin_y + absf(sin(_phase)) * _reglages.rebond * intensite

	# Un leger roulis du torse enleve l'impression de pantin.
	if _membres.has("Torse"):
		var t: Node3D = _membres["Torse"]
		t.rotation.z = s * deg_to_rad(_reglages.roulis_torse) * intensite


func _tourner(nom: String, angle: float) -> void:
	if _membres.has(nom):
		(_membres[nom] as Node3D).rotation.x = angle
