# Le son du jeu.
#
# Deux responsabilites, et une seule ligne de conduite : rien n'est ecrit en
# dur, tout vient de reglages.tres.
#
#   1. regler les volumes des bus
#   2. jouer la nappe d'ambiance, et fournir un point d'entree unique pour
#      les bruitages ponctuels
#
# Les sons positionnes dans l'espace ne passent PAS par ici : ils vivent sur
# l'objet qui les emet (moteur sur le vehicule, bourdonnement sur le
# lampadaire), sinon ils perdent leur position.
class_name Audio
extends Node

@export var reglages: Reglages

## Nappe jouee en continu a l'exterieur. Stereo, non positionnee.
@export var ambiance_exterieure: AudioStream

## Nappes d'interieur, indexees par nom de maison. Vide pour l'instant.
@export var ambiances_interieures: Dictionary = {}

const BUS_AMBIANCE := "Ambiance"
const BUS_EFFETS := "Effets"
const BUS_INTERFACE := "Interface"

const BANQUE := "res://donnees/sons.json"
const DOSSIER := "res://assets/sons/"

## Nom du groupe par lequel les autres systemes nous trouvent.
##
## Un NodePath exporte par systeme voulant du son aurait demande d'editer la
## scene principale a chaque fois — et la scene principale est le fichier que
## TOUTES les suites de tests rechargent. Un groupe se declare ici, une fois,
## et rien d'autre ne bouge.
const GROUPE := "audio"

var _ambiance: AudioStreamPlayer
var _fondu: Tween

## nom de mecanisme -> Array[AudioStream]. Chargee au demarrage, pas a la
## demande : un chargement de disque au moment ou l'on ouvre la roue s'entend
## comme un a-coup, et c'est precisement le moment ou le jeu est ralenti.
var _banque: Dictionary = {}

## Derniere variante tiree, par nom. Sert a ne jamais rejouer la meme deux
## fois de suite : c'est ce qui distingue quatre variantes d'un vrai hasard,
## lequel repete volontiers.
var _derniere: Dictionary = {}

## Noms reclames qui n'existent pas dans la banque. On ne rale qu'une fois
## par nom, sinon un son manquant dans une boucle noie la console.
var _inconnus: Dictionary = {}


func _ready() -> void:
	if reglages == null:
		push_error("audio : aucune ressource Reglages assignee")
		return
	add_to_group(GROUPE)
	appliquer_volumes()
	diagnostic()
	_charger_banque()
	_preparer_ambiance()


## Relit reglages.tres. Appelable a chaud comme le reste.
func appliquer_volumes() -> void:
	_regler("Master", reglages.volume_maitre)
	_regler(BUS_AMBIANCE, reglages.volume_ambiance)
	_regler(BUS_EFFETS, reglages.volume_effets)
	_regler("Musique", reglages.volume_musique)
	_regler(BUS_INTERFACE, reglages.volume_interface)


func _regler(nom: String, db: float) -> void:
	var index := AudioServer.get_bus_index(nom)
	if index < 0:
		push_error("audio : bus '%s' introuvable. La disposition des bus "
				% nom + "n'est pas chargee, tout le son passera au Master.")
		return
	AudioServer.set_bus_volume_db(index, db)
	AudioServer.set_bus_mute(index, false)


## Etat du son, imprime au demarrage. Sans ca, un jeu muet ne donne aucune
## piste : on ne sait meme pas si le probleme vient du fichier, du bus, du
## peripherique de sortie ou du volume.
func diagnostic() -> void:
	print("AUDIO : pilote '%s', melangeur %d Hz, sortie '%s'"
			% [AudioServer.get_driver_name(), AudioServer.get_mix_rate(),
			   AudioServer.get_output_device()])
	for i in AudioServer.bus_count:
		print("        bus %-10s %+6.1f dB%s"
				% [AudioServer.get_bus_name(i), AudioServer.get_bus_volume_db(i),
				   "  MUET" if AudioServer.is_bus_mute(i) else ""])


func _preparer_ambiance() -> void:
	# Un systeme audio muet ne se signale pas tout seul : c'est precisement
	# son mode de defaillance. Une premiere version sortait ici en silence
	# quand le flux manquait, et on cherchait la panne partout ailleurs.
	if ambiance_exterieure == null:
		push_error("audio : AUCUN flux d'ambiance charge. "
				+ "Le fichier est probablement un pointeur Git LFS non resolu, "
				+ "ou l'import Godot a echoue. Essayer : .\\bg.ps1 reparer")
		print("AUDIO : aucune ambiance. Voir le message d'erreur ci-dessus.")
		return

	var chemin := ambiance_exterieure.resource_path
	var duree := ambiance_exterieure.get_length()
	print("AUDIO : ambiance '%s', %.0f s" % [chemin.get_file(), duree])
	if duree < 0.5:
		push_error("audio : le flux '%s' dure %.2f s. "
				% [chemin, duree]
				+ "C'est le signe d'un fichier vide ou d'un pointeur LFS.")

	# La boucle se regle sur le flux lui-meme, pas sur le lecteur : une nappe
	# qui se relance depuis le debut a chaque fin s'entend, un flux marque
	# comme boucle ne se coupe jamais.
	if ambiance_exterieure is AudioStreamOggVorbis:
		(ambiance_exterieure as AudioStreamOggVorbis).loop = true
	elif ambiance_exterieure is AudioStreamWAV:
		(ambiance_exterieure as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

	_ambiance = AudioStreamPlayer.new()
	_ambiance.name = "Ambiance"
	_ambiance.stream = ambiance_exterieure
	_ambiance.bus = BUS_AMBIANCE
	add_child(_ambiance)

	# Demarrage en fondu : une nappe qui apparait a plein volume s'entend
	# comme un declic, et c'est la premiere seconde de jeu.
	_ambiance.volume_db = -60.0
	_ambiance.play()
	_fondu = create_tween()
	_fondu.tween_property(_ambiance, "volume_db", 0.0,
			maxf(0.01, reglages.ambiance_fondu))


## Bascule vers l'ambiance d'un interieur, ou revient dehors si le nom est
## vide. Le fondu evite la coupure nette au passage d'une porte.
func ambiance(nom: String = "") -> void:
	if _ambiance == null:
		return
	var flux: AudioStream = ambiances_interieures.get(nom, ambiance_exterieure)
	if flux == _ambiance.stream:
		return
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = create_tween()
	_fondu.tween_property(_ambiance, "volume_db", -60.0, 0.35)
	_fondu.tween_callback(func() -> void:
		_ambiance.stream = flux
		_ambiance.play())
	_fondu.tween_property(_ambiance, "volume_db", 0.0, 0.6)


## Retrouve le systeme audio depuis n'importe quel noeud de la scene.
##
## A APPELER A LA DEMANDE, JAMAIS DANS _ready().
##
## Godot appelle _ready() dans l'ordre de l'arbre, et le noeud Audio est
## declare apres le vehicule, le joueur, la roue et le telephone. Aucun d'eux
## n'existe encore dans le groupe au moment ou ils s'initialisent : tous
## recuperaient null, le gardaient, et restaient muets pour toute la partie.
##
## Rien ne le signalait. Chaque appel testait poliment `if _audio != null`, et
## un jeu silencieux ressemble a un jeu dont le son n'est pas encore branche.
## Le defaut a survecu a une suite de tests entiere consacree au son — elle
## interrogeait le groupe depuis la racine, ou il est bien la, au lieu de
## demander au vehicule s'il l'avait trouve.
static func courant(depuis: Node) -> Audio:
	if depuis == null or not depuis.is_inside_tree():
		return null
	return depuis.get_tree().get_first_node_in_group(GROUPE) as Audio


## Bruitage ponctuel non positionne : interface, dialogue. Le lecteur se
## supprime tout seul, on n'a pas a le gerer.
func jouer(flux: AudioStream, bus: String = BUS_INTERFACE,
		hauteur: float = 1.0) -> void:
	if flux == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = flux
	p.bus = bus
	p.pitch_scale = hauteur
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ---------------------------------------------------------------- la banque

func _charger_banque() -> void:
	if not FileAccess.file_exists(BANQUE):
		push_error("audio : %s introuvable" % BANQUE)
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANQUE))
	if typeof(lu) != TYPE_DICTIONARY:
		push_error("audio : %s illisible. Verifier les virgules." % BANQUE)
		return

	var manquants := 0
	for nom in (lu as Dictionary).get("banque", {}):
		var flux: Array[AudioStream] = []
		for fichier in (lu as Dictionary)["banque"][nom]:
			var chemin: String = DOSSIER + str(fichier)
			if not ResourceLoader.exists(chemin):
				# Franche, pas silencieuse : un fichier declare mais absent est
				# presque toujours un import Godot qui a echoue, et un jeu qui
				# se contente d'etre muet ne donne aucune piste.
				push_error("audio : '%s' declare pour '%s' est introuvable. "
						% [chemin, nom] + "Essayer : .\\bg.ps1 reparer")
				manquants += 1
				continue
			flux.append(ResourceLoader.load(chemin) as AudioStream)
		if not flux.is_empty():
			_banque[nom] = flux

	# Les nappes d'interieur viennent du meme fichier : elles etaient jusqu'ici
	# posees a la main dans la scene, donc invisibles pour qui cherchait "ou
	# est-ce qu'on decide du son de la maison de Walter".
	for nom in (lu as Dictionary).get("ambiances", {}):
		if nom.begins_with("_"):
			continue
		var chemin: String = DOSSIER + str((lu as Dictionary)["ambiances"][nom])
		if ResourceLoader.exists(chemin):
			ambiances_interieures[nom] = ResourceLoader.load(chemin) as AudioStream

	var variantes := 0
	for nom in _banque:
		variantes += (_banque[nom] as Array).size()
	print("AUDIO : banque de %d mecanisme(s), %d fichier(s)%s"
			% [_banque.size(), variantes,
			   ", %d MANQUANT(S)" % manquants if manquants > 0 else ""])


## Joue un son de la banque, sans position dans l'espace.
##
## C'est le point d'entree de tout le jeu : on nomme un MECANISME, jamais un
## fichier. Changer le son d'un cran de roue est alors une ligne de JSON, pas
## une modification de roue.gd.
func bruit(nom: String, bus: String = BUS_INTERFACE, hauteur: float = 1.0) -> void:
	var flux := _tirer(nom)
	if flux != null:
		jouer(flux, bus, hauteur)


## Meme chose, mais emis DEPUIS un point du monde. Une portiere qui claque
## derriere soi doit s'entendre derriere soi.
func bruit_ici(nom: String, position: Vector3, hauteur: float = 1.0) -> void:
	var flux := _tirer(nom)
	if flux == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = flux
	p.bus = BUS_EFFETS
	p.pitch_scale = hauteur
	p.unit_size = reglages.son_portee
	p.max_distance = reglages.son_distance_max
	add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()


## Le son existe-t-il ? Sert aux systemes qui composent un nom — « objet_%s »
## — et pour qui l'absence est un cas normal, pas une anomalie.
func connait(nom: String) -> bool:
	return _banque.has(nom)


func _tirer(nom: String) -> AudioStream:
	if not _banque.has(nom):
		if not _inconnus.has(nom):
			_inconnus[nom] = true
			push_warning("audio : aucun son nomme '%s'. L'ajouter dans %s"
					% [nom, BANQUE])
		return null

	var flux: Array = _banque[nom]
	if flux.size() == 1:
		return flux[0]

	# Tirage sans repetition immediate. Un vrai hasard rejoue la meme variante
	# deux fois de suite une fois sur quatre, et c'est exactement ce que les
	# variantes servent a eviter.
	var i := randi() % flux.size()
	if _derniere.get(nom, -1) == i:
		i = (i + 1) % flux.size()
	_derniere[nom] = i
	return flux[i]
