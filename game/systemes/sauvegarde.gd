# Sauvegarder et reprendre une partie.
#
# On ecrit ce qui doit survivre a une session : l'heure, l'argent, l'inventaire,
# la position, et l'etat de la mission. PAS le monde - il est genere et se
# refabrique a l'identique depuis sa graine, l'ecrire serait le plus gros du
# fichier pour rien. La sauvegarde vit dans user://, jamais dans le depot.
#
# QUAND on sauve : a la fin d'une mission (signal accomplie) et en quittant par
# le menu pause. Pas de sauvegarde libre - c'est un choix de design du ticket.
#
# QUAND on reprend : au lancement, si une sauvegarde existe, on la charge et on
# repose l'etat sans rejouer la mission depuis le debut.
#
# Ce qui n'est PAS encore la, et viendra quand ces systemes existeront : la
# purete, la famille, la reputation. Le format est un dictionnaire, on y ajoute
# une cle sans casser les sauvegardes ecrites avant.
class_name Sauvegarde
extends Node

const FICHIER := "user://partie.json"

## Version du format. Si sa forme change un jour, on saura lire l'ancienne ou
## la refuser proprement, au lieu de planter sur un champ absent.
const VERSION := 1

@export var bourse: NodePath
@export var temps: NodePath
@export var equipement: NodePath
@export var joueur: NodePath
@export var mission: NodePath

var _bourse: Bourse
var _temps: Temps
var _equipement: Equipement
var _joueur: Node3D
var _mission: Mission


func _ready() -> void:
	_bourse = get_node_or_null(bourse) as Bourse
	_temps = get_node_or_null(temps) as Temps
	_equipement = get_node_or_null(equipement) as Equipement
	_joueur = get_node_or_null(joueur) as Node3D
	_mission = get_node_or_null(mission) as Mission
	# On sauve a la fin d'une mission, sans que personne n'ait a y penser.
	if _mission and not _mission.accomplie.is_connected(sauver):
		_mission.accomplie.connect(sauver)
	# DIFFERE, et ce n'est pas une precaution : au lancement chaque systeme pose
	# son etat de depart dans son propre _ready(). Restaurer ici serait ecrase
	# une image plus tard. On attend que tout le monde soit pret.
	call_deferred("_reprendre_si_possible")


func existe() -> bool:
	return FileAccess.file_exists(FICHIER)


## Ecrit l'etat courant. Appele a la fin d'une mission et en quittant.
func sauver() -> void:
	var d := etat()
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f == null:
		push_error("sauvegarde : impossible d'ecrire %s" % FICHIER)
		return
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	print("SAUVEGARDE : %d $, heure %.1f, mission etape %d"
		% [d["argent"], d["heure"], d["mission"]["index"]])


## L'etat courant, en dictionnaire. Public : les tests le lisent sans fichier.
func etat() -> Dictionary:
	var d := {
		"version": VERSION,
		"heure": Reglages.heure,
		"argent": _bourse.montant() if _bourse else 0,
		"inventaire": {
			"possedes": _equipement.cles_possedees() if _equipement else [],
			"tenu": _equipement.cle_equipee() if _equipement else "",
			"portes": _equipement.cles_portees() if _equipement else [],
		},
		"mission": {
			"index": _mission.index() if _mission else 0,
			"faites": _mission.faites() if _mission else [],
		},
	}
	if _joueur:
		var p := _joueur.global_position
		d["position"] = [p.x, p.y, p.z]
	return d


## Efface la sauvegarde. Pour quand on recommence de zero.
func effacer() -> void:
	if existe():
		DirAccess.remove_absolute(FICHIER)


## Recharge la partie depuis le fichier, si elle existe. Public : c'est ce
## qu'on appelle a la reprise apres une mort. _reprendre_si_possible fait deja
## le travail ; recharger() lui donne un nom qui dit l'intention depuis dehors.
func recharger() -> void:
	_reprendre_si_possible()


func _reprendre_si_possible() -> void:
	if not existe():
		return
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(brut) != TYPE_DICTIONARY:
		push_error("sauvegarde : fichier illisible, ignore")
		return
	appliquer(brut)


## Repose l'etat d'une sauvegarde. Public : les tests s'en servent directement,
## sans passer par le fichier. Chaque champ est facultatif : une sauvegarde
## d'une version anterieure a laquelle il manque une cle ne plante pas.
func appliquer(d: Dictionary) -> void:
	if _temps and d.has("heure"):
		_temps.regler(float(d["heure"]))
	if _bourse and d.has("argent"):
		_bourse.poser(int(d["argent"]))
	if _equipement and d.has("inventaire"):
		var inv: Dictionary = d["inventaire"]
		_equipement.restaurer(inv.get("possedes", []), str(inv.get("tenu", "")),
			inv.get("portes", []))
	if _mission and d.has("mission"):
		var m: Dictionary = d["mission"]
		_mission.reprendre(int(m.get("index", 0)), m.get("faites", []))
	if _joueur and d.has("position"):
		var p: Array = d["position"]
		if p.size() == 3:
			_joueur.global_position = Vector3(
				float(p[0]), float(p[1]), float(p[2]))
	print("REPRISE : partie chargee")
