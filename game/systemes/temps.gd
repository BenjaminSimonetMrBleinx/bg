# L'heure du monde, et tout ce qui en depend.
#
# Un seul noeud avance l'heure et previent les autres. Sans ce point unique,
# chaque systeme relirait Reglages.nuit_part() a son rythme et ils
# divergeraient d'une image — le ciel deja bleu au-dessus de lampadaires encore
# allumes, ce qui se voit tout de suite.
#
# CE QUI A RENDU CECI POSSIBLE. Jusqu'a aujourd'hui l'etat des fenetres etait
# peint dans la couleur des facades : une texture de jour, une de nuit,
# choisies a la GENERATION. Changer d'heure aurait demande de refabriquer la
# ville. Les vitres allumees vivent maintenant dans un masque d'emission
# separe, que le jeu monte et descend — voir facade_vitres() dans
# outils/gen_textures.py.
#
# L'heure AVANCE, depuis le 30/07/2026. Elle etait figee — temps_vitesse a zero
# — parce qu'un cycle qui tourne pendant qu'on regle un curseur rend le reglage
# impossible a juger. C'etait vrai tant qu'on reglait ; ca ne l'est plus depuis
# qu'on joue. Le curseur reste, et le remettre a zero fige tout comme avant.
class_name Temps
extends Node

## Emis quand l'heure a change assez pour valoir un rafraichissement.
signal change(heure: float)

## Nom du groupe par lequel les autres systemes nous trouvent, comme pour
## l'audio. Aucun NodePath a cabler : un systeme qui veut l'heure la demande.
const GROUPE := "temps"

## Le groupe de CEUX QUI ECOUTENT. Ils recoivent heure_changee(nuit) a chaque
## rafraichissement, ou nuit va de 0 (plein jour) a 1 (nuit noire).
##
## Il existe parce que le rendu et la ville ne sont plus les seuls concernes :
## une lumiere de porche et des phares dependent aussi de l'heure, et ils sont
## instancies en cours de partie — une maison qu'on charge, une voiture dans
## laquelle on monte. Un NodePath par consommateur aurait demande de les cabler
## dans la scene, ce qu'on ne peut pas faire pour ce qui n'existe pas encore.
const ECOUTE := "heure_ecoute"

## En dessous de ce pas, en heures, on ne refait pas l'environnement. Refaire
## le ciel, le brouillard et le soleil a chaque image pour un centieme d'heure
## coute cher et ne se voit pas.
const PAS := 0.02

@export var reglages: Reglages

## Les systemes a prevenir. Facultatifs : sans eux, l'heure avance quand meme
## et rien ne plante.
@export var rendu: NodePath
@export var ville: NodePath

var _rendu: Node
var _ville: Node
var _derniere: float = -99.0


func _ready() -> void:
	add_to_group(GROUPE)
	_rendu = get_node_or_null(rendu)
	_ville = get_node_or_null(ville)
	if reglages == null:
		push_error("temps : aucune ressource Reglages assignee")
		set_process(false)
		return
	# DIFFERE, et ce n'est pas une precaution.
	#
	# Godot appelle _ready() des enfants AVANT celui du parent. Le rendu porte
	# son script sur le noeud racine, dont nous sommes un enfant : appeler son
	# appliquer() ici le surprend avant qu'il ait resolu son viewport, et il
	# rale sur un objet nul. Le jeu tournait quand meme — le rendu se
	# reconfigurait ensuite tout seul — mais deux erreurs partaient a chaque
	# lancement, et des erreurs qu'on apprend a ignorer sont des erreurs qu'on
	# n'ira pas lire le jour ou elles comptent.
	call_deferred("_appliquer", true)


func _process(delta: float) -> void:
	if reglages.temps_vitesse <= 0.0:
		return
	Reglages.heure = fposmod(Reglages.heure + reglages.temps_vitesse * delta, 24.0)
	_appliquer(false)


## Pose l'heure directement. Sert aux captures et aux tests : voir la ville a
## six heures ne doit pas demander d'attendre six heures.
func regler(h: float) -> void:
	Reglages.heure = clampf(h, 0.0, 24.0)
	_appliquer(true)


## L'heure, en texte, pour l'afficher.
func texte() -> String:
	var h := int(Reglages.heure)
	var m := int((Reglages.heure - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]


func _appliquer(force: bool) -> void:
	if not force and absf(Reglages.heure - _derniere) < PAS:
		return
	_derniere = Reglages.heure

	# Le rendu relit tout : ciel, brume, ambiante, soleil. Ses accesseurs
	# melangent deja jour et nuit selon l'heure, il n'y a rien a lui passer.
	if _rendu != null and _rendu.has_method("appliquer"):
		_rendu.call("appliquer")

	var nuit := Reglages.nuit_part()
	if _ville != null:
		if _ville.has_method("eclairer_fenetres"):
			_ville.call("eclairer_fenetres", nuit)
		if _ville.has_method("allumer_lampes"):
			_ville.call("allumer_lampes", nuit)

	# Tous les autres : maisons, vehicules, et ce qui viendra. call_group ne
	# rale pas sur un noeud qui n'a pas la methode, mais il ne rale pas non plus
	# quand PERSONNE ne l'a — d'ou le test qui compte les ecoutants.
	get_tree().call_group(ECOUTE, "heure_changee", nuit)

	change.emit(Reglages.heure)
