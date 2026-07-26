# L'argent de Walter.
#
# Un compteur, un signal, et deux verbes. C'est peu, et c'est exactement ce
# qu'il faut : l'argent est lu par le HUD, par la cachette et par la mission,
# et si chacun tenait son propre total ils divergeraient au premier oubli.
#
# Le son de gain est joue ICI plutot que par les appelants. Sinon il faudrait
# penser a le declencher a chaque endroit ou l'on gagne quelque chose, et on
# l'oublierait a l'un d'eux — celui qu'on ajoute dans six mois.
class_name Bourse
extends Node

signal change(montant: int)

const GROUPE := "bourse"

## En dessous de cette somme, on ne joue pas le son : rendre la monnaie n'est
## pas un evenement.
const SEUIL_SON := 1

var _montant: int = 0
var _audio: Audio


static func courante(depuis: Node) -> Bourse:
	if depuis == null or not depuis.is_inside_tree():
		return null
	return depuis.get_tree().get_first_node_in_group(GROUPE) as Bourse


func _ready() -> void:
	add_to_group(GROUPE)


func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio


func montant() -> int:
	return _montant


## Pose le total sans rien jouer. Pour le demarrage et pour recommencer une
## partie : entendre tinter la caisse au lancement du jeu n'a aucun sens.
func poser(valeur: int) -> void:
	_montant = maxi(0, valeur)
	change.emit(_montant)


func ajouter(somme: int) -> void:
	if somme <= 0:
		return
	_montant += somme
	if somme >= SEUIL_SON and _son() != null:
		_son().bruit("gain_argent")
	change.emit(_montant)


## Retire jusqu'a `somme`, et renvoie ce qui a REELLEMENT ete retire.
##
## Le retour compte : la cachette s'en sert pour ne ranger que ce qui existe.
## Une version qui renvoyait un booleen obligeait l'appelant a relire le total
## avant et apres, ce qu'il faisait parfois.
func retirer(somme: int) -> int:
	var pris := clampi(somme, 0, _montant)
	if pris <= 0:
		return 0
	_montant -= pris
	change.emit(_montant)
	return pris


## Formate une somme a l'americaine : 300000 devient « $300,000 ».
##
## Les separateurs comptent. A six chiffres colles, on lit « trente mille » une
## fois sur deux, et c'est le montant qui fait basculer la mission.
static func ecrire(somme: int) -> String:
	var chiffres := str(absi(somme))
	var sortie := ""
	var n := chiffres.length()
	for i in n:
		if i > 0 and (n - i) % 3 == 0:
			sortie += ","
		sortie += chiffres[i]
	return "$" + sortie
