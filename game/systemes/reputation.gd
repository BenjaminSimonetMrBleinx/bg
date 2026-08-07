# La reputation de rue.
#
# UNE SEULE REPUTATION, pas une par milieu. Ce qu'on suit, c'est ce que la rue
# raconte sur vous — pas ce que pense chaque dealer separement.
#
# ELLE NE SE DEPENSE JAMAIS. Seul l'argent se depense. La reputation est une
# PORTE : « reputation >= X » ouvre une mission, un contact, un prix, et ne
# consomme rien au passage. C'est ce qui la distingue d'une seconde monnaie.
#
# COMMENT ON LA GAGNE — decide le 06/08/2026, et c'est un MELANGE assume :
# la purete de ce qu'on livre, la fiabilite des livraisons, la violence
# assumee, et le fait de cuisiner de sa main plutot que de deleguer. Aucune de
# ces voies ne suffit seule, et c'est voulu : un joueur qui ne serait que
# violent, ou que rigoureux, plafonne.
#
# ELLE EST AFFICHEE, comme la famille et l'argent — decision du 06/08/2026,
# voir docs/12-direction.md. Les trois compteurs se lisent en permanence.
class_name Reputation
extends Node

signal change(points: int)

const GROUPE := "reputation"

const MINIMUM := 0
const MAXIMUM := 100
const DEPART := 10


static func courante(depuis: Node) -> Reputation:
	if depuis == null or not depuis.is_inside_tree():
		return null
	return depuis.get_tree().get_first_node_in_group(GROUPE) as Reputation


## Ce que chaque voie rapporte. Nombres de RESSENTI : ils finiront dans
## reglages.tres le jour ou on les reglera manette en main, et ils vivent ici
## groupes plutot que disperses dans le code.
##
## La livraison rapporte peu et souvent, la violence beaucoup et rarement :
## c'est ce qui fait qu'on peut monter en etant regulier OU en etant craint,
## mais pas en etant seulement l'un des deux.
const GAINS := {
	"livraison": 4,    # une livraison tenue, dans les temps
	"cuisine": 6,      # avoir cuisine de sa main plutot que delegue
	"violence": 9,     # avoir tenu tete, et l'avoir assume
	"parole": 3,       # avoir tenu parole a quelqu'un qui comptait
}

## Ce qu'on perd, et c'est rare. Reculer devant quelqu'un se sait ; deleguer se
## sait aussi, moins vite.
const PERTES = {
	"recul": 8,
	"delegue": 3,
	"livraison_ratee": 6,
	# ARRIVER EN RETARD PARCE QU'ON EST PASSE FAIRE LES COURSES.
	#
	# Moins cher qu'une livraison ratee : on arrive, mais on a fait attendre.
	# C'est le prix du detour de la mission 1 — sans lui, prendre les oeufs
	# serait meilleur sur tous les plans, et un choix sans cout n'est pas un
	# choix. Les deux compteurs bougent alors en sens inverse, cote a cote a
	# l'ecran : la famille monte quand on rentre, la rue baisse quand on tarde.
	"retard": 5,
}

## Ce que la purete ajoute a une livraison, par palier au-dessus du premier.
## Livrer du brun ne rapporte rien de plus ; livrer du bleu se raconte.
const PAR_PALIER := 3

## LE CHAPEAU EST UN INTERRUPTEUR. Coiffe, on est Heisenberg : tout ce qu'on
## fait se raconte plus vite. Le cout — se faire remarquer — se branchera sur
## la police (#35), et il n'existe pas encore : pour l'instant le chapeau est
## gratuit, ce qui est un desequilibre connu et assume.
const MULTIPLICATEUR_CHAPEAU := 1.5

@export var equipement: NodePath

var _points: float = float(DEPART)
var _equipement: Equipement


func _ready() -> void:
	add_to_group(GROUPE)
	_equipement = get_node_or_null(equipement) as Equipement
	change.emit(points())


func points() -> int:
	return roundi(_points)


## Porte-t-on le chapeau ? C'est la seule question que ce systeme pose a
## l'inventaire, et elle ne coute rien a demander.
func heisenberg() -> bool:
	return _equipement != null and _equipement.porte("chapeau")


## Une action qui compte. Le nom vient de GAINS ; un nom inconnu ne fait rien
## plutot que d'inventer une valeur. Renvoie ce qui a ete reellement ajoute.
func merci(quoi: String) -> int:
	var base := int(GAINS.get(quoi, 0))
	if base == 0:
		push_warning("reputation : '%s' n'est pas une voie connue" % quoi)
		return 0
	var gain := roundi(float(base) * (MULTIPLICATEUR_CHAPEAU if heisenberg() else 1.0))
	ajouter(gain)
	return gain


## Une livraison tenue, avec la purete de ce qu'on a livre. Les deux voies
## comptent dans le meme geste : etre fiable ET livrer du bon.
func livre(palier: int) -> int:
	var base := int(GAINS.get("livraison", 0)) + PAR_PALIER * maxi(0, palier - 1)
	var gain := roundi(float(base) * (MULTIPLICATEUR_CHAPEAU if heisenberg() else 1.0))
	ajouter(gain)
	return gain


## Ce qui se perd. Le chapeau ne protege de rien : reculer en Heisenberg se
## raconte aussi vite que le reste.
func tant_pis(quoi: String) -> int:
	var perte := int(PERTES.get(quoi, 0))
	if perte == 0:
		push_warning("reputation : '%s' n'est pas une perte connue" % quoi)
		return 0
	ajouter(-perte)
	return perte


func ajouter(n: int) -> void:
	_poser(_points + float(n))


func poser(n: int) -> void:
	_poser(float(n))


## La porte. C'est le seul usage prevu de la reputation : ouvrir, jamais payer.
func ouvre(seuil: int) -> bool:
	return points() >= seuil


func _poser(v: float) -> void:
	var avant := points()
	_points = clampf(v, float(MINIMUM), float(MAXIMUM))
	if points() != avant:
		change.emit(points())
